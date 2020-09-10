# frozen_string_literal: true

#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# TODO: keep this only until this is fixed https://github.com/middleman/middleman/issues/2312

require 'webrick'
require 'middleman-core/builder'

Middleman::Util.module_eval do
  module_function

  def normalize_path(path)
    return path unless path.is_a?(String)

    # The tr call works around a bug in Ruby's Unicode handling
    WEBrick::HTTPUtils.unescape(path).sub(%r{^/}, '').tr('', '')
  end
end

Middleman::Rack.class_eval do
  # https://github.com/middleman/middleman/blob/master/middleman-core/lib/middleman-core/rack.rb#L90
  def process_request(env, req, res) # rubocop:disable Metrics/AbcSize
    start_time = Time.now

    request_path = WEBrick::HTTPUtils.unescape(env['PATH_INFO'].dup)
    request_path.force_encoding('UTF-8') if request_path.respond_to? :force_encoding
    request_path = ::Middleman::Util.full_path(request_path, @middleman)
    full_request_path = File.join(env['SCRIPT_NAME'], request_path) # Path including rack mount

    # Run before callbacks
    @middleman.execute_callbacks(:before)

    # Get the resource object for this path
    resource = @middleman.sitemap.find_resource_by_destination_path(request_path.gsub(' ', '%20'))

    # Return 404 if not in sitemap
    return not_found(res, full_request_path) unless resource && !resource.ignored?

    # If this path is a binary file, send it immediately
    return send_file(resource, env) if resource.binary?

    res['Content-Type'] = resource.content_type || 'text/plain'

    begin
      # Write out the contents of the page
      res.write resource.render({}, rack: { request: req })

      # Valid content is a 200 status
      res.status = 200
    rescue Middleman::TemplateRenderer::TemplateNotFound => e
      res.write "Error: #{e.message}"
      res.status = 500
    end

    # End the request
    logger.debug "== Finishing Request: #{resource.destination_path} (#{(Time.now - start_time).round(2)}s)" # rubocop:disable Layout/LineLength
    halt res.finish
  end
end

Middleman::Builder.class_eval do
  def output_resource(resource) # rubocop:disable Metrics/AbcSize
    ::Middleman::Util.instrument 'builder.output.resource', path: File.basename(resource.destination_path) do # rubocop:disable Layout/LineLength
      output_file = @build_dir + resource.destination_path.gsub('%20', ' ')

      begin
        if resource.binary?
          export_file!(output_file, resource.file_descriptor[:full_path])
        else
          response = @rack.get(::URI.encode_www_form_component(resource.request_path))

          # If we get a response, save it to a tempfile.
          if response.status == 200
            export_file!(output_file, binary_encode(response.body))
          else
            trigger(:error, output_file, response.body)
            return false
          end
        end
      rescue StandardError => e
        trigger(:error, output_file, "#{e}\n#{e.backtrace.join("\n")}")
        return false
      end

      output_file
    end
  end
end

Middleman::Extensions::AssetHash.class_eval do
  def manipulate_single_resource(resource) # rubocop:disable Metrics/AbcSize
    return unless @exts.include?(resource.ext)
    return if ignored_resource?(resource)
    return if resource.ignored?

    digest = if resource.binary?
               ::Digest::SHA1.file(resource.source_file).hexdigest[0..7]
             else
               # Render through the Rack interface so middleware and mounted apps get a shot
               response = @rack_client.get(
                 ::URI.encode_www_form_component(resource.destination_path),
                 'bypass_inline_url_rewriter_asset_hash' => 'true'
               )

               raise "#{resource.path} should be in the sitemap!" unless response.status == 200

               ::Digest::SHA1.hexdigest(response.body)[0..7]
             end

    path, basename, extension = split_path(resource.destination_path)
    resource.destination_path = options.rename_proc.call(path, basename, digest, extension, options)
    resource
  end
end
