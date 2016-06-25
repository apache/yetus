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

set :markdown_engine, :redcarpet
set(
  :markdown,
  layout_engine:                :erb,
  with_toc_data:                true,
  smartypants:                  true,
  fenced_code_blocks:           true,
  no_intra_emphasis:            true,
  tables:                       true,
  autolink:                     true,
  quote:                        true,
  lax_spacing:                  true
)

set :build_dir, 'publish'

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

# classes needed to publish our api docs
class CopyInPlaceResource < ::Middleman::Sitemap::Resource
  def initialize(sitemap, dest, src)
    super(sitemap, dest, src)
  end

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

SHELLDOCS = File.absolute_path('../shelldocs/shelldocs.py')

def shelldocs(output, docs = [])
  unless FileUtils.uptodate?(output, docs) &&
         FileUtils.uptodate?(output, [SHELLDOCS])
    inputs = docs.map { |entry| "--input=#{entry}" }
    `#{SHELLDOCS} --skipprnorep --output #{output} #{inputs.join ' '}`
    unless $CHILD_STATUS.exitstatus == 0
      abort("shelldocs failed to generate docs for '#{docs}'")
    end
  end
end

RELEASEDOCMAKER = File.absolute_path('../release-doc-maker/releasedocmaker.py')

def releasenotes(output, version)
  # TODO: check jira for last update to the version and compare to source
  #       file timestamp
  `(cd #{output} && #{RELEASEDOCMAKER} --project=YETUS --version=#{version} \
                                       --projecttitle="Apache Yetus" \
                                       --usetoday --license --lint=all)`
  unless $CHILD_STATUS.exitstatus == 0
    abort("releasedocmaker failed to generate release notes for #{version}.")
  end
  FileUtils.mv("#{output}/#{version}/RELEASENOTES.#{version}.md",
               "#{output}/#{version}/RELEASENOTES.md")
  FileUtils.mv("#{output}/#{version}/CHANGES.#{version}.md",
               "#{output}/#{version}/CHANGES.md")
end

GITREPO = 'https://git-wip-us.apache.org/repos/asf/yetus.git'.freeze

def build_release_docs(output, version) # rubocop:disable Metrics/AbcSize
  # TODO: get the version date from jira and do an up to date check instead of building each time.
  puts "Building docs for release #{version}"
  puts "\tcleaning up output directories in #{output}"
  FileUtils.rm_rf("#{output}/build-#{version}", secure: true)
  FileUtils.rm_rf("#{output}/#{version}", secure: true)
  puts "\tcloning from tag."
  `(cd "#{output}" && \
    git clone --depth 1 --branch "rel/#{version}" --single-branch -- \
        "#{GITREPO}" "build-#{version}" \
   ) >"#{output}/#{version}_git_checkout.log" 2>&1`
  abort("building docs failed to for #{version}.") unless $CHILD_STATUS.exitstatus == 0
  puts "\tsetting up markdown docs"
  FileUtils.mkdir "#{output}/#{version}"
  FileUtils.mv(
    Dir.glob("#{output}/build-#{version}/asf-site-src/source/documentation/in-progress/*.md*"),
    "#{output}/#{version}/"
  )
  FileUtils.mv(
    "#{output}/build-#{version}/asf-site-src/source/documentation/in-progress.html.md",
    "#{output}/#{version}.html.md"
  )
  FileUtils.mkdir "#{output}/#{version}/precommit-apidocs"
  precommit_shelldocs(
    "#{output}/#{version}/precommit-apidocs",
    "#{output}/build-#{version}/precommit"
  )

  puts "\tgenerating javadocs"
  `(cd "#{output}/build-#{version}/audience-annotations-component" && mvn -DskipTests -Pinclude-jdiff-module javadoc:aggregate) >"#{output}/#{version}_mvn.log" 2>&1` # rubocop:disable Metrics/LineLength
  unless $CHILD_STATUS.exitstatus == 0
    puts "\tgenerating javadocs failed. maybe maven isn't installed? look in #{output}/#{version}_mvn.log" # rubocop:disable Metrics/LineLength
  end
end

def precommit_shelldocs(apidocs_dir, source_dir)
  # core API
  shelldocs("#{apidocs_dir}/core.md", Dir.glob("#{source_dir}/core.d/*.sh"))
  # smart-apply-patch API
  shelldocs("#{apidocs_dir}/smart-apply-patch.md", ["#{source_dir}/smart-apply-patch.sh"])
  # primary API
  shelldocs("#{apidocs_dir}/test-patch.md", ["#{source_dir}/test-patch.sh"])
  # plugins API
  shelldocs("#{apidocs_dir}/plugins.md", Dir.glob("#{source_dir}/test-patch.d/*.sh"))
end

# Add in apidocs rendered by other parts of the repo
after_configuration do
  # This allows us to set the style for tables.
  ::Middleman::Renderers::MiddlemanRedcarpetHTML.class_eval do
    def table(header, body)
      '<table class=\'table table-bordered table-striped\'>' \
        "<thead>#{header}</thead>" \
        "<tbody>#{body}</tbody>" \
      '</table>'
    end
  end

  # For Audiene Annotations we just rely on having made javadocs with Maven
  sitemap.register_resource_list_manipulator(
    :audience_annotations,
    ApiDocs.new(
      sitemap,
      'documentation/in-progress/audience-annotations-apidocs',
      '../audience-annotations-component/target/site/apidocs'
    )
  )

  # For Precommit we regenerate source files so they can be rendered.
  # we rely on a symlink. to avoid an error from the file watcher, our target
  # has to be outside of hte asf-site-src directory.
  # TODO when we can, update to middleman 4 so we can use multiple source dirs
  # instead of symlinks
  FileUtils.mkdir_p '../target/in-progress/precommit-apidocs'
  precommit_shelldocs('../target/in-progress/precommit-apidocs', '../precommit')
  unless data.versions.releases.nil?
    data.versions.releases.each do |release|
      build_release_docs('../target', release)
      releasenotes('../target', release)
      # stitch the javadoc in place
      sitemap.register_resource_list_manipulator(
        "#{release}_javadocs".to_sym,
        ApiDocs.new(
          sitemap,
          "documentation/#{release}/audience-annotations-apidocs",
          "../target/build-#{release}/audience-annotations-component/target/site/apidocs"
        )
      )
    end
  end
end
