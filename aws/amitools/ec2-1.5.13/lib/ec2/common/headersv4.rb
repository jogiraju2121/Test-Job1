# Copyright 2008-2014 Amazon.com, Inc. or its affiliates.  All Rights
# Reserved.  Licensed under the Amazon Software License (the
# "License").  You may not use this file except in compliance with the
# License. A copy of the License is located at
# http://aws.amazon.com/asl or in the "license" file accompanying this
# file.  This file is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See
# the License for the specific language governing permissions and
# limitations under the License.

#
# A class to contain headers and sign them with signature version 4
# This code is a shameless copy of our SDK's signature version 4 code base
#

require 'cgi'
require 'uri'
require 'time'
require 'base64'
require 'tempfile'
require 'digest/md5'
require 'openssl'
require 'digest'
require 'digest/sha2'

module EC2
  module Common
    class HeadersV4
      # Create an HttpHeaderV4,
      # values = {
      #   :host -> http host
      #   :hexdigest_body -> hexdigest of the http request's body
      #   :region -> region of the endpoint
      #   :service -> the service that should recieve this request
      #   :http_method -> http method
      #   :path -> URI
      #   :querystring -> Everything after ? in URI
      #   :access_key_id -> access key
      #   :secret_access_key -> secret access kry
      #   [optional] :fixed_datetime -> Fix the datetime using DateTime object, do not use Time.now
      # }
      # For more info see:
      # http://docs.aws.amazon.com/general/latest/gr/signature-version-4.html
      def initialize values, headers={}
        @headers = headers
        @host = values[:host]
        @hexdigest_body = values[:hexdigest_body]
        @region = values[:region]
        @service = values[:service]
        @http_method = values[:http_method]
        @path = values[:path]
        @querystring = values[:querystring]
        @access_key_id = values[:access_key_id]
        @secret_access_key = values[:secret_access_key]
        @fixed_datetime = values[:fixed_datetime]
      end

      def add_authorization!
        datetime = get_datetime
        @headers['host'] = @host
        @headers['x-amz-date'] = datetime
        @headers['x-amz-content-sha256'] ||= @hexdigest_body || EC2::Common::HeadersV4::hexdigest('')
        @headers['authorization'] = authorization(datetime)
        @headers
      end

      def authorization datetime
        parts = []
        parts << "AWS4-HMAC-SHA256 Credential=#{credential(datetime)}"
        parts << "SignedHeaders=#{signed_headers}"
        parts << "Signature=#{signature(datetime)}"
        parts.join(', ')
      end

      def signature datetime
        k_secret = @secret_access_key
        k_date = hmac("AWS4" + k_secret, datetime[0,8])
        k_region = hmac(k_date, @region)
        k_service = hmac(k_region, @service)
        k_credentials = hmac(k_service, 'aws4_request')
        hexhmac(k_credentials, string_to_sign(datetime))
      end

      def string_to_sign datetime
        parts = []
        parts << 'AWS4-HMAC-SHA256'
        parts << datetime
        parts << credential_string(datetime)
        parts << EC2::Common::HeadersV4::hexdigest(canonical_request)
        parts.join("\n")
      end

      def credential datetime
        "#{@access_key_id}/#{credential_string(datetime)}"
      end

      def credential_string datetime
        parts = []
        parts << datetime[0,8]
        parts << @region
        parts << @service
        parts << 'aws4_request'
        parts.join("/")
      end

      def canonical_request
        parts = []
        parts << @http_method
        parts << @path.gsub('%2F', '/')
        parts << canonical_querystring
        parts << canonical_headers + "\n"
        parts << signed_headers
        parts << @headers['x-amz-content-sha256']
        parts.join("\n")
      end

      def signed_headers
        to_sign = @headers.keys.map{|k| k.to_s.downcase}
        to_sign.delete('authorization')
        to_sign.sort.join(";")
      end

      def canonical_querystring
        CGI::parse(@querystring).sort_by{|k,v| CGI::escape(k)}.map do |v|
          value = v[1][0] || ""
          "#{CGI::escape(v[0])}=#{CGI::escape(value)}"
        end.join('&')
      end

      def canonical_headers
        headers = []
        @headers.each_pair do |k,v|
          k_lower = k.downcase
          headers << [k_lower,v] unless k_lower == 'authorization'
        end
        headers = headers.sort_by{|k,v| k}
        headers.map{|k,v| "#{k}:#{canonical_header_values(v)}"}.join("\n")
      end

      def canonical_header_values values
        values = [values] unless values.is_a?(Array)
        values.map{|v|v.to_s}.join(',').gsub(/\s+/, ' ').strip
      end

      def hmac key, value
        OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new('sha256'), key, value)
      end

      def hexhmac key, value
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('sha256'), key, value)
      end

      def get_datetime
        return @fixed_datetime.strftime("%Y%m%dT%H%M%SZ") if @fixed_datetime != nil
        Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
      end

      # Returns a SHA256 hexdigest of value.
      # Should be used to hexdigest body of http request.
      def self.hexdigest value, chunk_size = 1024 * 1024
        digest = Digest::SHA256.new
        if value.respond_to?(:read)
          chunk = nil
          digest.update(chunk) while chunk = value.read(chunk_size)
          value.rewind
        else
          digest.update(value)
        end
        digest.hexdigest
      end
    end
  end
end
