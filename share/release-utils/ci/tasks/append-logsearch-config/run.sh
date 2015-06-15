#!/bin/bash

set -e
set -u

cd create-release/repo/

RELEASE_DIR=$PWD /usr/local/logsearch-shipper-release-utils/run

TGZ=$( find *releases -name '*.tgz' )
TAR=$( echo "${TGZ}" | sed 's/tgz$/tar/' )

gzip -d ${TGZ}
tar -rf ${TAR} logsearch-config
gzip ${TAR}

mv ${TAR}.gz ${TGZ}
