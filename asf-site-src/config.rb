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

# Per-page layout changes:
#
# With no layout
# page "/path/to/file.html", :layout => false
#
# With alternative layout
# page "/path/to/file.html", :layout => :otherlayout
#
# A path which all have the same layout
# with_layout :admin do
#   page "/admin/*"
# end

set :markdown_engine, :redcarpet
set :markdown, :layout_engine => :erb,
               :tables => true,
               :autolink => true,
               :smartypants => true,
               :fenced_code_blocks => true,
               :with_toc_data => true

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
class CopyInPlaceResource<Middleman::Sitemap::Resource
  def initialize (sitemap, dest, src)
    super(sitemap, dest, src)
  end
  def binary?
    return true
  end
end

class ApiDocs
  def initialize (sitemap, destination, source)
    @sitemap=sitemap
    @destination=destination
    @source=source
  end
  def manipulate_resource_list(resources)
    parent=Pathname.new(@source)
    build=Pathname.new("documentation/in-progress/#{@destination}")
    Middleman::Util::all_files_under(@source).each do  |path|
      dest = build + path.relative_path_from(parent)
      resources << CopyInPlaceResource.new(@sitemap, dest.to_s, path.to_s)
    end
    # to make clear what we return
    return resources
  end
end

def shelldocs(output, docs=[])
  unless FileUtils.uptodate? output, docs
    inputs=docs.map do |entry| "--input=#{entry}" end
    `../shelldocs/shelldocs.py --skipprnorep --output #{output} #{inputs.join ' '}`
  end
end

RELEASEDOCMAKER = File.absolute_path('../release-doc-maker/releasedocmaker.py')

def releasenotes(output, version)
  # TODO: check jira for last update to the version and compare to source
  #       file timestamp
  `(cd #{output} && #{RELEASEDOCMAKER} --project=YETUS --version=#{version} \
                                       --projecttitle="Apache Yetus" \
                                       --usetoday --license --lint)`
  FileUtils.mv("#{output}/#{version}/RELEASENOTES.#{version}.md",
               "#{output}/#{version}/RELEASENOTES.md")
  FileUtils.mv("#{output}/#{version}/CHANGES.#{version}.md",
               "#{output}/#{version}/CHANGES.md")
end

# Add in apidocs rendered by other parts of the repo
after_configuration do
  # For Audiene Annotations we just rely on having made javadocs with Maven
  sitemap.register_resource_list_manipulator(:audience_annotations, ApiDocs.new(sitemap, "audience-annotations-apidocs", "../audience-annotations-component/target/site/apidocs"))
  # For Precommit we regenerate source files so they can be rendered.
  FileUtils.mkdir_p 'source/documentation/in-progress/precommit-apidocs'
  # core API
  shelldocs('source/documentation/in-progress/precommit-apidocs/core.md', Dir.glob("../precommit/core.d/*.sh"))
  # smart-apply-patch API
  shelldocs('source/documentation/in-progress/precommit-apidocs/smart-apply-patch.md', ['../precommit/smart-apply-patch.sh'])
  # primary API
  shelldocs('source/documentation/in-progress/precommit-apidocs/test-patch.md', ['../precommit/test-patch.sh'])
  # plugins API
  shelldocs('source/documentation/in-progress/precommit-apidocs/plugins.md', Dir.glob('../precommit/test-patch.d/*.sh'))
  unless data.versions.releases.nil?
    data.versions.releases.each do |release|
      releasenotes('source/documentation', release)
    end
  end
end
