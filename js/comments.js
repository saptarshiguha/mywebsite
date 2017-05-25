$('#commentform').submit(process);

function process(event) {
	event.preventDefault();
  $('#commentform-alert').children().remove();
  var name = $('#commentform-author').val().trim();
  var email = $('#commentform-email').val().trim();
  var url = $('#commentform-url').val().trim();
  var comment = $('#commentform-comment').val().trim();
  if (validate(name, email, url, comment)) {
    $('#commentform-submit').prop('disabled', true);
    $('#commentform-submit').after(' <i class="fa fa-spinner fa-spin fa-lg"></i>');
	  $.ajax({
	    type: 'POST',
	    url: 'https://da8oorcu64.execute-api.us-west-2.amazonaws.com/prod',
	    contentType: 'application/json',
		  data: JSON.stringify({
			  name: name,
			  email: email,
			  url: url,
			  postId: $('#commentform-post-id').val(),
			  comment: comment
		  }),
	    dataType: 'json',
	    success: function (url) {
        clearForm();
        $('#commentform-alert').append('<p class="alert alert-success"><i class="fa fa-info-circle"></i> Your comment has been <a href="' + url + '">submitted for review</a>.</p>');
        $('#commentform-submit').prop('disabled', false);
        $('#commentform-submit').next().remove();
	    },
	    error: function () {
        $('#commentform-alert').append('<p class="alert alert-error"><i class="fa fa-exclamation-circle"></i> Your comment could not be submitted. Please try again later.</p>');
        $('#commentform-submit').prop('disabled', false);
        $('#commentform-submit').next().remove();
	    }
	  });
  }
}

function validate(name, email, url, comment) {
  if (name == '') {
    $('#commentform-alert').append('<p class="alert alert-error"><i class="fa fa-exclamation-circle"></i> A name is required.</p>');
    return false;
  } else if (email.indexOf('@') < 1) {
    $('#commentform-alert').append('<p class="alert alert-error"><i class="fa fa-exclamation-circle"></i> An email address is required.</p>');
    return false;
  } else if (comment == '') {
    $('#commentform-alert').append('<p class="alert alert-error"><i class="fa fa-exclamation-circle"></i> Your comment does not contain any text.</p>');
    return false;
  }
  return true;
}

function clearForm() {
  $('#commentform-author').val('');
  $('#commentform-email').val('');
  $('#commentform-url').val('');
  $('#commentform-comment').val('');
}
