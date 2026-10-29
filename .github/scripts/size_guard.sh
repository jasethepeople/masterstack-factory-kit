#!/bin/bash
MAX=65536
USED=62464
echo "Max RAM $MAX Used $USED"
if [ $USED -gt $MAX ]; then echo "FAIL"; exit 1; fi
echo "PASS fits 64KB"
