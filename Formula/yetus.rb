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
# Homebrew formula to install Apache Yetus
class Yetus < Formula
  desc 'Enable contribution and release processes for software projects'
  homepage 'https://yetus.apache.org/'
  url 'https://www.apache.org/dyn/closer.lua?path=/yetus/0.7.0/yetus-0.7.0-bin.tar.gz'
  sha256 '619655979b9c05c0f739d43dbf7bcf657d90239a6577e1b167aceb6596bb506d'

  option 'with-all', 'Build with all dependencies. Note that some dependencies such as '\
    'Perl::Critic, Pylint, RuboCop and ruby-lint still need to be installed manually.'

  dependencies = [
    # programming languages
    :java,
    'scala',

    # build tools
    'ant',
    'autoconf',
    'automake',
    'cmake',
    'libtool',
    'gradle',
    'maven',

    # test tools
    'findbugs',
    'shellcheck'
  ]

  dependencies.each do |dependency|
    if build.with?('all')
      depends_on dependency
    else
      depends_on dependency => :optional
    end
  end

  def install
    rm Dir['bin/*.{bat,cmd,dll,exe}']
    inreplace Dir['bin/*'], '$(dirname -- "${BASH_SOURCE-0}")/..', libexec
    libexec.install Dir['*']
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    system "#{bin}/qbt", '--version'
    system "#{bin}/releasedocmaker", '-V'
    system "#{bin}/shelldocs", '-V'
    system "#{bin}/smart-apply-patch", '--version'
    system "#{bin}/test-patch", '--version'
  end
end
