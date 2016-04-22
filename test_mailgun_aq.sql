-- Note: mailgun_aq_pkg requires your mailgun settings to be compiled into
--       mailgun_pkg. It is recommended that you add calls to populate them
--       using your own code (instead of hardcoding your private key in the
--       code).

-- set up mailgun AQ
begin
  mailgun_aq_pkg.create_queue;
  mailgun_aq_pkg.create_job;
end;
/

-- send a simple email
begin
  mailgun_aq_pkg.send_email
    (p_from_email => 'Mr Sender <sender@example.com>'
    ,p_to_email   => 'Ms Recipient <recipient@example.com>'
    ,p_subject    => 'test subject ' || to_char(systimestamp,'DD/MM/YYYY HH24:MI:SS.FF')
    ,p_message    => 'Test Email Body'
    );
  commit;
end;
/

-- push the queue
begin
  mailgun_aq_pkg.push_queue;
end;
/

-- purge failed messages
begin
  mailgun_aq_pkg.purge_queue;
end;
/

-- send an email using all the options, including priority
begin
  mailgun_aq_pkg.send_email
    (p_from_name  => 'Mr Sender'
    ,p_from_email => 'sender@example.com'
    ,p_reply_to   => 'reply@example.com'
    ,p_to_name    => 'Mr Recipient'
    ,p_to_email   => 'recipient@example.com'
    ,p_cc         => 'Mrs CC <cc@example.com>'
    ,p_bcc        => 'Ms BCC <bcc@example.com>'
    ,p_subject    => 'test subject ' || to_char(systimestamp,'DD/MM/YYYY HH24:MI:SS.FF')
    ,p_message    => '<html><body><strong>Test Email Body</strong>'
                  || '<p>'
                  || '<a href="' || mailgun_pkg.unsubscribe_link_tag || '">Unsubscribe</a>'
                  || '</body></html>'
    ,p_tag        => 'testtag2'
    ,p_priority   => 1
    );
  mailgun_aq_pkg.push_queue;
end;
/

-- send an email to multiple recipients; each recipient will only see their own
-- name in the "To" field (but they will see the "CC" recipient)
begin
  mailgun_pkg.send_to('Mr Recipient <recipient1@example.com>', p_id => 'id1');
  mailgun_pkg.send_to('bob.jones@example.com', p_first_name => 'Bob', p_last_name => 'Jones', p_id => 'id2');
  mailgun_pkg.send_to('jane.doe@example.com', p_first_name => 'Jane', p_last_name => 'Doe', p_id => 'id3');
  mailgun_pkg.send_cc('cc@example.com');
  mailgun_pkg.send_bcc('bcc@example.com','Mr Bcc');
  mailgun_aq_pkg.send_email
    (p_from_email => 'Mr Sender <sender@example.com>'
    ,p_subject    => 'test subject ' || to_char(systimestamp,'DD/MM/YYYY HH24:MI:SS.FF')
    ,p_message    => 'Hi ' || mailgun_pkg.recipient_first_name || ','
                  || '<p>'
                  || 'This is the email body.'
                  || '<p>'
                  || 'This email was sent to ' || mailgun_pkg.recipient_name || '.'
                  || '<br>'
                  || 'Reference: ' || mailgun_pkg.recipient_id
    );
  mailgun_aq_pkg.push_queue;
exception
  when others then
    mailgun_pkg.reset; -- clear any recipients from memory
    raise;
end;
/

-- send an email with some attachments
declare
  clob_content clob;
  blob_content blob;
begin

  -- generate a largish text file
  dbms_lob.createtemporary(clob_content,false);
  clob_content := lpad('x', 32767, 'x');
  dbms_lob.writeappend(clob_content, 32767, lpad('y',32767,'y'));
  dbms_lob.writeappend(clob_content, 3, 'EOF');
  dbms_output.put_line('file size=' || dbms_lob.getlength(clob_content));

  -- load a binary file
  -- source: https://github.com/mortenbra/alexandria-plsql-utils/blob/master/ora/file_util_pkg.pkb
  blob_content := alex.file_util_pkg.get_blob_from_file
    (p_directory_name => 'MY_DIRECTORY'
    ,p_file_name      => 'myimage.jpg');

  mailgun_pkg.attach
    (p_file_content => 'this is my file contents'
    ,p_file_name    => 'myfilesmall.txt'
    ,p_content_type => 'text/plain');

  mailgun_pkg.attach
    (p_file_content => clob_content
    ,p_file_name    => 'myfilelarge.txt'
    ,p_content_type => 'text/plain');

  mailgun_pkg.attach
    (p_file_content => blob_content
    ,p_file_name    => 'myimage.jpg'
    ,p_content_type => 'image/jpg'
    ,p_inline       => true);

  mailgun_aq_pkg.send_email
    (p_from_email => 'Mr Sender <sender@example.com>'
    ,p_to_email   => 'Mrs Recipient <recipient@example.com>'
    ,p_subject    => 'test subject ' || to_char(systimestamp,'DD/MM/YYYY HH24:MI:SS.FF')
    ,p_message    => '<html><body><strong>Test Email Body</strong>'
                  || '<p>'
                  || 'There should be 2 attachments and an image below.'
                  || '<p>'
                  || '<img src="cid:myimage.jpg">'
                  || '</body></html>'
    );

  mailgun_aq_pkg.push_queue;

exception
  when others then
    mailgun_pkg.reset; -- clear any attachments from memory
    raise;
end;
/
