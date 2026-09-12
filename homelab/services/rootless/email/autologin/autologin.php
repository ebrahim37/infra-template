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
    }

    public function startup($args)
    {
        if (empty($_SESSION['user_id'])) {
            $args['task'] = 'login';
            $args['action'] = 'login';
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
}
