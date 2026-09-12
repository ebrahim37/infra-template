<?php

/** Automatically open the shared mailbox; access control is external to Roundcube. */
class autologin extends rcube_plugin
{
    public $task = '';

    #[\Override]
    public function init()
    {
        $this->add_hook('startup', [$this, 'startup']);
        $this->add_hook('authenticate', [$this, 'authenticate']);
        $this->add_hook('login_after', [$this, 'login_after']);
    }

    public function startup($args)
    {
        if (empty($_SESSION['user_id'])) {
            $args['task'] = 'login';
            $args['action'] = 'login';
        } elseif ($args['task'] === 'mail' && empty($args['action']) && !isset($_REQUEST['_mbox'])) {
            $_GET['_mbox'] = 'gmail main/INBOX';
            $_REQUEST['_mbox'] = 'gmail main/INBOX';
        }

        return $args;
    }

    public function authenticate($args)
    {
        $rcmail = rcmail::get_instance();
        $result = $rcmail->get_dbh()->query(
            'SELECT username FROM ' . $rcmail->db->table_name('users') . ' ORDER BY user_id LIMIT 1'
        );
        $user = $rcmail->get_dbh()->fetch_assoc($result);

        $args['user'] = $user['username'] ?? 'me';
        $args['pass'] = '1234';
        $args['cookiecheck'] = false;
        $args['valid'] = true;
        $args['abort'] = false;

        return $args;
    }

    public function login_after($args)
    {
        $args['_task'] = 'mail';
        $args['_mbox'] = 'gmail main/INBOX';

        return $args;
    }
}
