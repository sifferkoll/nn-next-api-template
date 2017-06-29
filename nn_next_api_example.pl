#!/usr/bin/perl

#
# Nordnet nExt API example using Perl
# info@sifferkoll.se - http://sifferkoll.se
#

use JSON;
use utf8::all;
use MIME::Base64;
use REST::Client;
use Crypt::PK::RSA;
use URL::Encode qw(url_encode_utf8);
use IO::Socket::SSL;
use URI::Query;

$url='https://www.nordnet.se';
$pubKey='yourKey.pem';
$service='NEXTAPI';
$path='/next/2/';

$accNo=$nordnetAccount{accountNumber};
$login=$nordnetAccount{login};
$passw=$nordnetAccount{pw};

$ts=time()*1000;
$ts64=encode_base64($ts,'' );

$login64=encode_base64($login,'');
$passw64=encode_base64($passw,'');

$authString=$login64.':'.$passw64.':'.$ts64;

$public = Crypt::PK::RSA->new($pub);
$encrypted = $public->encrypt($authString,'v1.5');
$authEncrypt=encode_base64($encrypted,'');
$authURL=url_encode_utf8($authEncrypt);

$bodyStr='auth='.$authURL.'&service='.$service;

$head{Accept}='application/json';

#
# REST API login
#

$client=REST::Client->new();
$client->setHost($url);
$client->POST(
    $path.'login',
    $bodyStr,
    \%head
    );

$resp = from_json $client->responseContent();

$pubFeedHost=$$resp{public_feed}{hostname};
$pubFeedPort=$$resp{public_feed}{port};
$session=$$resp{session_key};

#
# basic auth for REST API / and session for feed
#

$basicAuth = 'Basic ' . encode_base64($session.":".$session,'');
$head{Authorization}=$basicAuth;

$$cmd{cmd}='login';
$$cmd{args}{session_key}=$session;

$loginString=to_json $cmd;

#
# Example Using REST API to get account info
#

$client->GET(
    $path.'accounts/'.$accNo,
    \%head
    );

$accountJson = $client->responseContent();
$accountHash = from_json $accountJson;

#
# Example POST order
#

# Nordnet specific $identifier and $market_id for the instrument
$bodyStr="identifier=".$identifier."&market_id=".$market_id."&";

# add the rest of the variables in $orderObject hashref as of the API
$uri = URI::Query->new($orderObject);
$bodyStr.=$uri;

$client->POST(
    $path.'accounts/'.$accNo.'/orders',
    $bodyStr,
    \%head
    );

$resp=from_json $client->responseContent();            
$orderId=$$resp{order_id};

#
# fork off a process for public data listening
#

unless ($pubPid = fork){

    $sock=IO::Socket::SSL->new($pubFeedHost.":".$pubFeedPort);
    
    # login on socket    
    print $sock $loginString."\n";
    
    #
    # subscribe to price, trade, depth, trading_status for list of instruments
    #
    
    foreach $a (@hashrefArray_of_instruments){
	
	undef $subs;
	
	$$subs{cmd}='subscribe';
	$$subs{args}{i}=$$a{i};  #identifier
	$$subs{args}{m}=$$a{m};  #market_id
	
	foreach $type ('price','trade','depth','trading_status'){
	    $$subs{args}{t}=$type;
	    $subsString=to_json $subs;
	    print $sock $subsString."\n";
	}    
    }
    
    # and listen 
    
    while(<$sock>){
	
	$data=from_json $_;
	
	# do whatever forever with the $data hashref
	
    }
    
} 
