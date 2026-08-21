<?php

// Let the user choose a provider on Roundcube's login screen.
$config['imap_host'] = [
    'ssl://imap.gmail.com:993' => 'Gmail',
    'ssl://imap.mail.me.com:993' => 'iCloud',
];

// Send through the SMTP service matching the selected IMAP provider.
$config['smtp_host'] = [
    'imap.gmail.com' => 'ssl://smtp.gmail.com:465',
    'imap.mail.me.com' => 'tls://smtp.mail.me.com:587',
];
$config['smtp_user'] = '%u';
$config['smtp_pass'] = '%p';

$config['product_name'] = 'Roundcube Webmail';
$config['enable_installer'] = false;
$config['session_samesite'] = 'Lax';
