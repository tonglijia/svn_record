jQuery ($) ->
	$('.contextual .toggle_code').click ->
		$('.contextual .autoscroll').toggle('sile')
		return false
	$('.changeset-changes ul li:first a:first').attr('href', '/develop/repository/changes');
