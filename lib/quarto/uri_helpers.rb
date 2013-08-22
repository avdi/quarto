require "base64"

module Quarto
  module UriHelpers
    module_function
    def data_uri_for_file(file, type)
      data         = File.read(file)
      encoded_data = Base64.strict_encode64(data)
      uri          = "data:#{type};base64,"
      uri << encoded_data
      uri
    end
  end
end
