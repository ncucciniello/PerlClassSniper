sub help {
  $message = "

  Using: perl -w webadv_alert.pl <arguments>

    where <arguments> are the following separated by a space:
      -Term          : which semester the class is in, e.g. \"20/SP - 2020 Spring\"
      -Subject       : which Subject the class is in, e.g. \"ENGLISH (EN)\"
      -Course Number : course number, e.g., 202
      -Section Number: course section, e.g., 51
      -Email address : alert recipient's email address, e.g. test\@test.com

      or

      --help         : display script usage

    \n";

  print $message;
}

sub checkterm {
  $input = $_[0];

  if (my ($matched) = grep $_ eq $input, @terms) {
    $term = $ARGV[0];
  }
  else {
    print "Term entered is invalid. \nValid terms are: \n";

    foreach $term (sort @terms) {
      print "  $term \n";
    }
    exit(1);
  }
}

######## End of subroutines #######

$numargs = $#ARGV + 1;

if ($numargs < 5 || $ARGV[0] =~ /--help/) {
  help();
  exit(1);
}

use WWW::Mechanize;
use Mail::Sendmail;

$url = "https://www2.monmouth.edu/muwebadv/wa3/search/SearchClassesV2.aspx";
$mech = WWW::Mechanize->new();
$mech->get($url);

# Get term options
$content = $mech->content();

# Using option tag to find terms and add them to terms array
@terms = $content =~ /<option value="[0-9]{2,}.*\/[A-Z]{2,}">(.*)<\/option>/g;

# Check if term input is valid
checkterm($ARGV[0]);

# Select the term
$mech->field("_ctl0:MainContent:ddlTerm", $term);

# Select the subject
$subject = $ARGV[1];
$mech->field("_ctl0:MainContent:ddlSubj_1", $subject);

# Select the course number
$coursenumber = $ARGV[2];
$mech->field("_ctl0:MainContent:txtCourseNum_1", $coursenumber);

# Select the section number
$sectionnumber = $ARGV[3];
$mech->field("_ctl0:MainContent:txtSectionNum_1", $sectionnumber);

# "Click" the Submit button
$mech->click_button(name => "_ctl0:MainContent:btnSubmit");

# Get resulting html
$searchresult = $mech->content();

# Check if searched class exist
if ( $searchresult =~ /<span id="MainContent_lblMsg" class="errorText">No classes meeting the search criteria have been found.<\/span>/ ) {
  print "That class does not exist. \n";
  help();
}

$email = $ARGV[4];

@subjectcode = $subject =~ /\((.*)\)/;
$class = $subjectcode[0] ."-". $coursenumber ."-" . $sectionnumber;

%mail = ( To      => $email,
          From    => 'ClassSniper@monmouth.edu',
          Subject => $class . ' is open!',
          Message => 'The class (' . $class . ') you are monitoring for the ' . $term . ' semester has opened!

Monmouth University Class Sniper
created by Nico Cucciniello'
        );

# Check status of searched class
if ( $searchresult =~ /<td>Clsd.*?<\/td>/ ) {
  print "Class is closed \n";
}
if ( $searchresult =~ /<td>Open.*?<\/td>/ ) {
  if (sendmail %mail) {
    print "Mail sent OK.\n"
  }
  else {
    print "Error sending mail: $Mail::Sendmail::error \n"
  }
}
