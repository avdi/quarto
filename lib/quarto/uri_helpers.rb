require "base64"
require "mime/types"

module Quarto
  module UriHelpers
    module_function
    def data_uri_for_file(file, type=guess_type_of_file(file))
      data         = File.read(file)
      encoded_data = Base64.strict_encode64(data)
      uri          = "data:#{type};base64,"
      uri << encoded_data
      uri
    end

    def guess_type_of_file(file)
      MIME::Types.type_for(file).first
    end
  end
end
