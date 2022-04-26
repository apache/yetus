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

require 'ruby27_fix_uri'
require 'kramdown-parser-gfm'

set :markdown_engine, :kramdown
# rubocop:disable Layout/HashAlignment
set(
  :markdown,
  input:                        'GFM',
  layout_engine:                :erb,
  with_toc_data:                true,
  fenced_code_blocks:           true,
  no_intra_emphasis:            true,
  tables:                       true,
  autolink:                     true,
  quote:                        true,
  lax_spacing:                  true,
  relative_links:               true
)
# rubocop:enable Layout/HashAlignment

set :build_dir, 'target/site'

set :css_dir, 'assets/css'
set :js_dir, 'assets/js'
set :images_dir, 'assets/img'

# Build-specific configuration
configure :build do
  activate :relative_assets
end

activate :directory_indexes
activate :syntax
activate :livereload

# Per-page layout changes
page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false
page '.htaccess.apache', layout: false

# classes needed to publish our api docs
class CopyInPlaceResource < ::Middleman::Sitemap::Resource
  def binary?
    true
  end
end

# Generate API documentation from the rest of the source tree
class ApiDocs
  def initialize(sitemap, destination, source)
    @sitemap = sitemap
    @destination = destination
    @source = source
  end

  def manipulate_resource_list(resources)
    parent = Pathname.new(@source)
    build = Pathname.new(@destination)
    ::Middleman::Util.all_files_under(@source).each do |path|
      dest = build + path.relative_path_from(parent)
      resources << CopyInPlaceResource.new(@sitemap, dest.to_s, path.to_s)
    end
    # to make clear what we return
    resources
  end
end

SHELLDOCS = File.absolute_path('../shelldocs/src/main/python/shelldocs.py')

def shelldocs(output, docs = [])
  unless FileUtils.uptodate?(output, docs) &&
         FileUtils.uptodate?(output, [SHELLDOCS])
    inputs = docs.map { |entry| "--input=#{entry}" }
    `#{SHELLDOCS} --skipprnorep --output #{output} #{inputs.join ' '}`
    errmsg = $stderr
    return if $CHILD_STATUS.exitstatus.zero?

    puts(errmsg)
    abort("shelldocs failed to generate docs for '#{docs}'")
  end
end

def fetch_release_docs(output, version)
  puts "Downloading and extracting #{version} from ASF archives"
  `(cd #{output} \
    && mkdir -p site/documentation/#{version} \
    && curl --fail --location --output site-#{version}.tar.gz \
    https://archive.apache.org/dist/yetus/#{version}/apache-yetus-#{version}-site.tar.gz \
    && tar -C site/documentation/#{version} \
    --strip-components 3 -xzpf site-#{version}.tar.gz \
    apache-yetus-#{version}-site/documentation/in-progress/ \
    )`
end

def precommit_shelldocs(apidocs_dir, source_dir)
  # core API
  shelldocs("#{apidocs_dir}/core.html.md", Dir.glob("#{source_dir}/core.d/*.sh"))
  # smart-apply-patch API
  shelldocs("#{apidocs_dir}/smart-apply-patch.html.md", ["#{source_dir}/smart-apply-patch.sh"])
  # primary API
  shelldocs("#{apidocs_dir}/test-patch.html.md", ["#{source_dir}/test-patch.sh"])
  # plugins API
  shelldocs("#{apidocs_dir}/plugins.html.md", Dir.glob("#{source_dir}/plugins.d/*.sh"))
end

# Add in apidocs rendered by other parts of the repo
after_configuration do
  # Since `after_configuration` runs twice in middleman 4,
  # we will build twice if we don't skip the config run
  next if app.config[:mode] == :config

  # This allows us to set the style for tables.
  ::Middleman::Renderers::MiddlemanKramdownHTML.class_eval do
    def convert_table(el, indent) # rubocop:disable Naming/MethodParameterName
      el.attr['class'] = 'table table-bordered table-striped'
      super
    end
  end

  # For Precommit we regenerate source files so they can be rendered.
  # we rely on a symlink. to avoid an error from the file watcher, our target
  # has to be outside of the asf-site-src directory.
  # TODO when we can, update to middleman 4 so we can use multiple source dirs
  # instead of symlinks
  FileUtils.mkdir_p 'target/in-progress/precommit/apidocs/'
  precommit_shelldocs('target/in-progress/precommit/apidocs/', '../precommit/src/main/shell')
end

after_build do
  File.rename 'target/site/.htaccess.apache', 'target/site/.htaccess'
  File.rename(
    'target/site/documentation/in-progress/precommit/apidocs-index/index.html',
    'target/site/documentation/in-progress/precommit/apidocs/index.html'
  )
  app.data.versions.releases&.each do |release|
    fetch_release_docs('target', release)
  end
end
