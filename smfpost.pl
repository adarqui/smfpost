#!/usr/bin/perl

=begin header
/* smfpost - library for manipulation of binary trees.
   Copyright (C) 1998, 1999, 2000, 2001, 2002, 2004 Free Software
   Foundation, Inc.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
   02110-1301 USA.

   Author: Andrew Darqui (adarq.org)
*/
=end header
=cut header

use LWP::UserAgent; 
use HTTP::Cookies;
use Data::Dumper;
use HTML::Form;
use Getopt::Long;

%config;

$config{"url"} = "http://www.adarq.org/";
$config{"user"} = "darqbot";
$config{"pass"} = "darqbot";
$config{"subforum"} = "the-hole";
#$config{"topic"} = "random-thoughts-from-irc";
$config{'topic'} = "posted-from-darqbot";
$config{'subject'} = '';
$config{'agent'} = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)";
$config{'ua'}; # user agent
$config{'env'}; # username:password env
$config{'verbose'} = 0;
$config{'help'} = 0;

$config{'msg'} = '';
$config{'file'} = '';

%res;
$res{'last_msg'};
$res{'logout'};
$res{'phpses'};
$res{'host'};




# OPTIONS

GetOptions (
	'verbose!' => \$config{'verbose'},
	'user=s' => \$config{'user'},
	'pass=s' => \$config{'pass'},
	'url=s' => \$config{'url'},
	'subforum=s' => \$config{'subforum'},
	'sf=s' => \$config{'subforum'},
	'topic=s' => \$config{'topic'},
	'subject=s' => \$config{'subject'},
	'agent=s' => \$config{'agent'},	
	'message=s' => \$config{'msg'},
	'msg=s' => \$config{'msg'},
	'm=s' => \$config{'m'},
	'file=s' => \$config{'file'},
	'f=s' => \$config{'file'},
	'env=s' => \$config{'env'},
	'e=s' => \$config{'e'},
	'help' => \$config{'help'},
	'h' => \$config{'help'},
	);


	if($config{'help'} > 0) {
		help();
	}

	if($config{'verbose'}) {
		print "[v] config hash: " . Dumper \%config;
	}

	if($config{'env'}) {
		@tokens = split(/:/, $ENV{'SMFPOST'});
		$config{'user'} = @tokens[0];
		$config{'pass'} = @tokens[1];
		$ENV{'SMFPOST'} = "";
	}

	if(!$config{'user'} || !$config{'pass'}) { print "i\n"; exit(-1); }

	if($config{'file'}) {
		my $input_fh;
		open( $input_fh, "<", $config{'file'} ) || die "[x] Can't open $config{'file'}: $!";	
		my @lines = <$input_fh>;
		$config{'msg'} = join('', @lines);	
	}
	
	if(!$config{'msg'}) {
		print "[x] Please provide a message or file to post.\n";
		exit (0);
	}

	if(length($config{'msg'}) > 100) {
		print "[+] We will attempt to post: [" . substr($config{'msg'}, 0, 100) . "...truncated]\n";
	}
	else {
		print "[+] We will attempt to post: [$config{'msg'}]\n";
	}



### Login, post, then logout. skwad.

	login_smf();

	post_smf();

	sleep (1);

	logout_smf();

	print "[+] Done.\n";

	exit(0);



sub help{
	print 
"[+] Help:
	--verbose	:	enable verbose reporting
	--user		:	username
	--pass		:	password
	--url		:	base url, ie, http://adarq.org/
	--subforum	:	which subforum to post in (--sf also)
	--topic		:	which topic to post in or create
	--subject	:	the subject of the thread or reply
	--agent		:	specify a custom USER_AGENT
	--message	:	specify the message to post in the thread (--msg & --m also)
	--file		:	specifies a file to read from to create the message to post (--f also)
	--env		:	specifiy username:password in \$SMFPOST environment variable (--e also)
	--help		:	this help menu (--h also)
";

	exit(0);
}

sub logout_smf{

	$res{'host'} = $config{'url'};
	$res = $config{'ua'}->get($res{'host'});

	my $a = $res->as_string;
	my $new_url = $config{'url'} . 'logout/';

	if( $a =~ m/$new_url(.*)\"/) {
		$res_logout = $1;
	}

    $res{'host'} = $config{'url'} . "logout/" . $res_logout;
    $res = $config{'ua'}->post($res{'host'});

	if($config{'verbose'}) {
		print "[v] XXX logout_smf: Logout:\n";
		print Dumper $res;
		print "\n";
	}

	print "[+] Logged out.\n";
}



sub post_smf{

    $config{'ua'}->default_header(
       'Referer' => $config{'url'} . $config{'subforum'},
    );

	### CHECK SUBFORUM FIRST ###

	$res{'host'} = $config{'url'} . $config{'subforum'};
	$res = $config{'ua'}->get($res{'host'});
	
    if($config{'verbose'}) {
        print "[v] XXX post_smf: verify subforum\n";
        print Dumper $res;
        print "\n";
    }


	if($res->status_line == 404 || !$res->is_success) {
		print "[x] Subforum doesn't exist\n";
		return;
	}
	
	# make sure sub-forum always has one trailing /, fix this.. #
	if($res->content =~ m/\"$res{'host'}\/\"/ig) {
		print "[+] Subforum exists. Next.\n";
	}
	else {
		print "[x] Subforum doesn't exist.\n";
		return;
	}


	### CHECK TO SEE IF THREAD EXISTS ###

	$res{'host'} = $config{'url'} . $config{'subforum'} . "/" . $config{'topic'};
	$res = $config{'ua'}->get($res{'host'});

    if($config{'verbose'}) {
        print "[v] XXX post_smf: verify thread\n";
        print Dumper $res;
        print "\n";
    }


	if($res->status_line == 404 || !$res->is_success) {
		print "[x] Topic doesn't exist. exiting.\n";
		return;
	}
	
	if($res->content =~ m/\"$res{'host'}\/\"/ig) {
		print "[+] Topic exists. Next.\n";
	}
	else {
		print "[x] Topic doesn't exist.\n";

			$config{'subject'} = $config{'topic'};

		print "[+] Topic will be created.\n";
	}

	
	### Begin process of posting ###


    $res{'host'} = $config{'url'} . $config{'subforum'} . "/" . $config{'topic'} . "/?action=post";
    $res = $config{'ua'}->get($res{'host'});

	if($config{'verbose'}) {
		print "[v] XXX post_smf: action=post\n";
		print Dumper $res;
		print "\n";
	}

	my @form = HTML::Form->parse($res);
	my $form0 = @form[0];

	my @hidden;
	my @form_out;

	foreach(@form) {

		@inputs = $_->inputs;
		for (my $i=0; $i<=$#inputs ; $i++) {
			$inp = $inputs[$i];

			if($config{'verbose'}) {
				print "[v] Input value [$i] => " . $inp->name . " = " . $inp->value . "\n";
			}

			if(($inp->type eq "hidden") && $inp->value) { 
				push(@form_out, $inp->name, $inp->value);
			}
			if (($inp->name eq "subject") && $inp->value && !$config{'subject'}) {
				push(@form_out, $inp->name, $inp->value);
				print "WTF" . $inp->name . "\n";
			}
		}
	}

### SAFE

#	push(@form_out, "subject", "FML");
	push(@form_out, "postmodify", "0");
	push(@form_out, "icon", "xx");
#	push(@form_out, "num_replies", "99999999");
	push(@form_out, "message", $config{'msg'});
#	push(@form_out, "message_mode", "0");
#	push(@form_out, "notify", "0");
#	push(@form_out, "lock", "0");
#	push(@form_out, "sticky", "0");
#	push(@form_out, "move", "0");
	push(@form_out, "additional_options", "0");

	if($config{'subject'}) {
		push(@form_out, "subject", $config{'subject'});
	}

	if($config{'verbose'}) {
		print "[v] form_out variables:\n";
		print Dumper \@form_out;
		print "\n";
	}

### SAFE

### SAFE

	$res{'host'} = $config{'url'} . $config{'subforum'} . "/?action=post2;start=0";
    $res = $config{'ua'}->post($res{'host'} , \@form_out);

	if($config{'verbose'}) {
    	print "[v] XXX post_smf: action=post2\n\n";
		print Dumper $res;
		print "\n";
	}

	print "[+] Posted!\n";
}




sub login_smf{

	my $target = $config{'url'} . "index.php";

	$res{'host'} = "$target?action=login";
	$config{'ua'} = LWP::UserAgent->new(agent => $config{'agent'}, itimeout => 10);

	$res = $config{'ua'}->get($res{'host'});
	$res{'phpses'} = get_setcookie($res->as_string());
	$config{'ua'}->default_header(
		'Accept' => "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5",
		'Accept-Charset' => "ISO-8859-1,utf-8;q=0.7,*;q=0.7",
		'Keep-Alive' => '115',
		'Connection' => 'keep-alive',
		'Referer' => "$target?action=login2",
		'Cookie' => "PHPSESSID=$res{'phpses'}"
	);

	$res{'host'} = "$target?PHPSESSID=" . $res{'phpses'} . "&action=login2";
	$res = $config{'ua'}->post($res{'host'}, [
		'user' => $config{'user'},
		'passwrd' => $config{'pass'},
		'cookieneverexp' => 'on',
		'hash_passwrd' => ''
		]
	);

    if($config{'verbose'}) {
        print "[v] XXX login_smf: login\n";
        print Dumper $res;
        print "\n";
    }


	print "===========================================\n";
	print "[+] Host : $target\n";
	print "[+] Login in $config{'user'}..\n";
	print "[+] Pass in $config{'password'}..\n";
	$ct = $res->content();
	$config{'ua'}->default_header('Cookie' => set_cookie($res->as_string()));

	$res = $config{'ua'}->get($target);


	if($res->content() =~ m/$config{'user'}/ig){
		print "[+] Success...!\n";
	}
	else{
		print "[+] Failed..\n";
	}

}



sub get_setcookie{
	my $var = $_[0]; 
	if($var =~ /Set-Cookie: PHPSESSID=(.+);/){
		return $1;
	}
}



sub set_cookie{
	my $var = $_[0];
	if($var =~m/Set-Cookie: ([^;]+);[^;]+/){
		$smf = $1;
		$var =~s/Set-Cookie: $1//ig;
	}

	if($var =~m/Set-Cookie: ([^;]+)/){
		$res{'phpses'} = $1;
	}

	return $res{'phpses'} . "; " . $smf;
}




sub readFile{
	my @var;
	my ($file) = @_;
	open FILE, "<:utf8", "$file" or die "[+] Can't open $file : $!"; while(){
		my $line = $_;
		$line =~ s/\r|\n//g;
		next if (length($line) == 0);
		push(@var,$line);
	}

	close FILE;
	return(@var);
}
