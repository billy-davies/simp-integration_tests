require 'json'

module Simp
  module Beaker
    class NodesetHelpers
      def initialize(host)
        @env_box_tag = "BEAKER_box__#{host}"
        @env_box_url  = "BEAKER_box_url__#{host}"
        @env_box_tree = 'BEAKER_vagrant_box_tree'
      end

      # Attempts to derive the box_url from the ENV variable
      # `BEAKER_box_url__{host}`
      # @return [String] if the URL could be determined
      # @return [nil] if the URL could not be determined
      def box_url_from__env_box_url
        return nil unless (box_url = ENV[@env_box_url])
        box_url
      end

      # Attempts to derive the box_url from the ENV variables
      # `BEAKER_box_tree` and `BEAKER_box__{host}`
      # @return [String] if the URL could be determined
      # @return [nil] if the URL could not be determined
      def box_url_from__env_box_tree
        box_tree = ENV[@env_box_tree] || ''
        box_tag  = ENV[@env_box_tag]  || ''
        return nil if box_tree.empty? || box_tag.empty?
        names = box_tag.split('/')
        # NOTE: This probably breaks net URLs when run from a Windows host:
        File.join box_tree, names.first, 'boxes', "#{names.last}.json"
      end

      # return the proper box_url or fail with instructions
      def box_url
        box_url = box_url_from__env_box_url || box_url_from__env_box_tree
        if box_url
          warn '', '-' * 80, '', "box_url = '#{box_url}'", '', '-' * 80, ''
          return box_url
        end
        fail_with_env_var_instructions 'Could not determine box_url from ENV vars'
      end

      # Attempts to derive the correct box_name from either:
      #     * The ENV var `BEAKER_box__{host}` (if it is set)
      #     * The basename of `box_url`
      #   If the box_name cannot be determined, the method prints usage
      #   instructions and fails.
      # @return [String] The box name
      def box_name
        return File.basename(ENV[@env_box_tag]) if ENV[@env_box_tag]
        unless (box_url = box_url_from__env_box_url)
          fail_with_env_var_instructions 'Could not determine box_name (or box_url) from ENV vars'
        end
        require 'open-uri' # enables `open()` to handle URLs *and* local files
        require 'json'

        box_metadata_data = if box_url =~ %r{\Ahttps?://}
                              URI.parse(box_url).read
                            else
                              File.read(box_url.sub(%r{\Afile://}, ''))
                            end

        box_metadata = JSON.parse(box_metadata_data)
        box_metadata['name']
      end

      def fail_with_env_var_instructions(error)
        raise(<<MSG.gsub(%r{^ {10}}, '')
          --------------------------------------------------------------------------------
          ERROR: #{error}
          --------------------------------------------------------------------------------

          SIMP Beaker integration tests MUST set certain environment variables.

          Either set these:

            # The base of a local vagrantcloud-ish directory tree
            #{@env_box_tree}=/PATH/TO/BOXES/DIR_TREE

            # the org/name of the box
            #{@env_box_tag}=simpci/BOX_NAME


          Or set this:

            # box version metadata (vagrantcloud-ish)
            #{@env_box_url}=/PATH/TO/BOX.json

          Notes:
          * `/PATH` can be anything that is accepted by Beaker nodesets and Vagrantfiles,
            including URLs starting with 'file://', 'http://', or 'https://'.
          * `#{@env_box_tree}` can be generated by the simp-packer rake task,
            `rake vagrant:publish:local`

          --------------------------------------------------------------------------------

MSG
             )
      end
      # rubocop:reenable Metrics/MethodLength
    end
  end
end
