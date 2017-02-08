#!/bin/sh

rm test-mutex.log -f
ruby ./caller_normal.rb &
ruby ./caller_normal.rb &
ruby ./caller_normal.rb &
