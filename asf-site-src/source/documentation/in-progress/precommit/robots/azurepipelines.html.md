<!---
  Licensed to the Apache Software Foundation (ASF) under one
  or more contributor license agreements.  See the NOTICE file
  distributed with this work for additional information
  regarding copyright ownership.  The ASF licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.
-->

# Robots: Azure Pipelines

    NOTE: Azure Pipelines support is not stable and should be viewed as experimental, at best.

TRIGGER: ${TF_BUILD}=True

Azure Pipelines support has only been tested on the Ubuntu VM with GitHub as the source repository. It automatically configures `--patch-dir` to be `${BUILD_ARTIFACTSTAGINGDIRECTORY}/yetus`.  While the URL to the console is provided in the report, links are not provided due to the URLs to artifacts not being available at runtime.
