#!/bin/bash

if [ -z "$1" ]; then
  COMMAND=make
else
  COMMAND="$@"
fi

if [ -z "$CONTAINER_IMAGE_DOMINO_CAPI" ]; then
  CONTAINER_IMAGE_DOMINO_CAPI=hclcom/domino:latest
fi

docker run -it --rm -w /build --entrypoint= -v $(pwd):/build -u 0 -e LOTUS=/opt/hcl/domino -e Notes_ExecDirectory=/opt/hcl/domino/notes/latest/linux -e LD_LIBRARY_PATH=/opt/hcl/domino/notes/latest/linux -e INCLUDE=/opt/hcl/domino/notesapi/include "$CONTAINER_IMAGE_DOMINO_CAPI" $COMMAND
