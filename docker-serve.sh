#!/bin/sh

docker run -i -t --rm \
    --name jekyll-test \
    -v $PWD:/srv/jekyll \
    -p 4000:4000 \
    jekyll/jekyll \
    bundle exec jekyll serve -w
