# Xapi-project Docs [![Build Status](https://travis-ci.org/xapi-project/xapi-project.github.io.png)](https://travis-ci.org/xapi-project/xapi-project.github.io)

Documentation for the architecture of the Xapi toolstack.

## Viewing the documentation

This documentation is written in markdown and built with Jekyll. If you wish to
browse the documentation, you can do so via the Github interface. Or, if you
prefer, you can view the rendered output which is hosted using Github Pages.

## Contributing documentation

This repository is treated differently by Github. Due to its name, the `master`
branch of this repository is compiled with Jekyll and hosted at
[https://xapi-project.github.io/](https://xapi-project.github.io/).

Documentation is written in markdown and can be placed in a semantically
meaningful place in the directory hierarchy.

A page must have the YAML front-matter for it to be compiled by Jekyll. The
following boilerplate at the top of the file should suffice:

```yaml
---
layout: default
title: [title of page]
---
```

Then, if you want the page to be accessible in the navigation menu, you need to
make the following addition to `_data/navbar.yml`:

```diff
  - title: Section Name
    docs:
    - foo.md
+   - path/to/your-new-doc.md
```

## Contributing design proposals

Design proposals for new features and amendments to existing features can also
be added to this repository. These will normally be more verbose in nature and
contain more justification of decisions than a normal API doc. They may also
not yet be in the toolstack so we want to keep them separate. To create such
a document create a Markdown file in a place of your choosing with the
following YAML front-matter:

```yaml
---
layout: default
title: [title of page]
design_doc: true
status: [proposed|confirmed|released (version#)]
revision: [iteration of document]
---
```

## Previewing documentation before pushing

If you wish to preview the site that will be generated before pushing, you can
do so from your own machine. First install ruby:

```bash
$ apt-get install ruby ruby-dev
$ gem install bundler [--user-install]

```

Then navigate to the root directory of this repository and run

```bash
$ bundle install [--path <installation path>]
```

and then you can host the site locally as follows:

```bash
$ bundle exec jekyll serve -w --baseurl '/xapi-project'
```

You will then be able to view the page at `localhost:4000/xapi-project`.

For more detailed setup (or if you do not have the correct prerequisite ruby environment, check out [these instructions](https://help.github.com/articles/using-jekyll-with-pages/#installing-jekyll).

## A note on images
If you are contributing images, consider compressing them to keep this repo as
slim as possible:

```
convert -resize 900 -background white -colors 256 [input.png] [output.png]
```

If you wish to include a message sequence chart, consider using
[js-sequence-diagrams](http://bramp.github.io/js-sequence-diagrams/) and
check in the created .svg.

## Adding links to other parts of the site
Relative links should work, but should you wish to refer to a page outside of
the current section, you should prepend `{{site.baseurl}}` so that it will work
in whichever repo we choose to host it and also when viewed locally.
