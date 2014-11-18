# Xapi-project Docs

Documentation for the architecture of the Xapi toolstack.

## Viewing the documentation
This documentation is written in markdown and built with Jekyll. If you wish to
browse the documentation, you can do so via the Github interface. Or, if you
prefer, you can view the rendered output which is hosted using Github Pages.

## Contributing documentation
This repository is treated differently by Github. Due to its name, the `master`
branch of this repository is compiled with Jekyll and hosted at
[http://xapi-project.github.io/].

Documentation is written in markdown and can be placed in a semantically
meaningful place in the directory hierarchy.

A page must have the YAML front-matter for it to be compiled by Jekyll. The
following boilerplate at the top of the file should suffice:

```
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

## Previewing documentation before pushing

If you wish to preview the site that will be generated before pushing, you can
do so from your own machine.

Install Jekyll:

```
$ gem install jekyll
```

Then you can host the site locally with the following command from the root
directory of this repository:
```
$ jekyll serve -w --baseurl '/xapi-project'
```

You will then be able to view the page at `localhost:4000/xapi-project`.
