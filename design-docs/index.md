---
title: Design Docs Index
layout: default
---

Here is a collection of design docs that formed the process of a feature's
creation/revision.

These are likely to be more technical in nature and may include more
justification of design decisions than the other docs on this site.

<div class="alert">
<button type="btn" class="close" data-dismiss="alert">&times;</button>
<strong>Key: </strong> <span class="label">Revision</span> <span class="label label-info">XenServer version</span>
</div>

<table class="table tabl-striped table-condensed">
{% for p in site.pages | group_by:"xs_release" %}
  {% if p.design_doc %}
<tr><td>
<a href={{p.url}} class="btn btn-link">{{p.title}}</a> {% if p.revision != null %} <span class="label">v{{p.revision}}</span> {% endif %} {% if p.xs_release != null %} <span class="label label-info">{{p.xs_release}}</span> {% endif %}
</td></tr>
  {% endif %}
{% endfor %}
</table>
