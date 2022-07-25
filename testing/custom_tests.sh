#!/bin/bash

# Example custom test command

ERROR_MSG=

header "Custom test command"
echo "Container CMD : $CONTAINER_CMD"
echo "Domino Volume : $DOMINO_VOLUME"

#ERROR_MSG="Just setting an error text will make the test fail"

test_result "custom.check" "Custom Check" "" "$ERROR_MSG"

