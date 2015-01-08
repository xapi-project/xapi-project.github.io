/*
 * Copyright (C) 2006-2009 Citrix Systems Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; version 2.1 only. with the special
 * exception on linking described in file LICENSE.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 */

function make_title() {
	document.write('<title>Xapi Documentation</title>');
}

function make_header(t) {
	if (t == 'apidoc')
		title = 'Xapi &ndash; XenAPI Documentation';
	else if (t == 'codedoc')
		title = 'Xapi &ndash; OCaml Code Documentation';
	else
		title = 'Xapi &ndash; Documentation';

	html = '<h1 style="float:left; font-size: 24px;"><a href="index.html">XenServer Management API</a></h1>'
	document.getElementById('header').innerHTML = html;
}

function get_release_name(s)
{
	switch (s) {
	case 'rio':
		return 'XenServer 4.0';
		break;
	case 'miami':
		return 'XenServer 4.1';
		break;
	case 'symc':
		return 'XenServer 4.1.1';
		break;
	case 'orlando':
		return 'XenServer 5.0';
		break;
	case 'orlando-update-1':
		return 'XenServer 5.0 Update 1';
		break;
	case 'george':
		return 'XenServer 5.5';
		break;
	case 'midnight-ride':
		return 'XenServer 5.6 (XCP 0.5)';
		break;
	case 'cowley':
		return 'XenServer 5.6 FP1 (XCP 1.0)';
		break;
	case 'boston':
		return 'XenServer 6.0 (XCP 1.5)';
		break;
	case 'tampa':
		return 'XenServer 6.1 (XCP 1.6)';
		break;
	case 'clearwater':
		return 'XenServer 6.2';
		break;
	case 'vgpu-tech-preview':
		return 'XenServer 6.2 vGPU preview';
		break;
	case 'vgpu-productisation':
		return 'XenServer 6.2 SP1';
		break;
	case 'clearwater-felton':
		return 'XenServer 6.2 SP1 Hotfix 4';
		break;
	case 'clearwater-whetstone':
		return 'XenServer 6.2 SP1 Hotfix 11';
		break;
	case 'creedence':
		return 'XenServer 6.5';
		break;
	default:
		return (s + ' (unreleased)');
		break;
	}
}

