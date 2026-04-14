import { connect } from 'cloudflare:sockets';

export async function sendEmail(
  to: string,
  subject: string,
  text: string,
  env: { SMTP_USER?: string; GMAIL_APP_PASSWORD?: string; EMAIL_SENDER?: string },
  html?: string
) {
  const { SMTP_USER, GMAIL_APP_PASSWORD, EMAIL_SENDER } = env;

  if (!SMTP_USER || !GMAIL_APP_PASSWORD || !EMAIL_SENDER) {
    throw new Error('Email configuration missing');
  }

  const host = 'smtp.gmail.com';
  const port = 465; // Use 465 for SMTPS (direct TLS)

  const socket = connect({ hostname: host, port: port }, { secureTransport: 'on' });
  const writer = socket.writable.getWriter();
  const reader = socket.readable.getReader();
  const decoder = new TextDecoder();
  const encoder = new TextEncoder();

  async function send(cmd: string) {
    await writer.write(encoder.encode(cmd + '\r\n'));
  }

  async function receive() {
    const { value } = await reader.read();
    return decoder.decode(value);
  }

  try {
    // Wait for greeting
    await receive();

    // HELO
    await send('EHLO localhost');
    await receive();

    // AUTH LOGIN
    await send('AUTH LOGIN');
    await receive();

    await send(btoa(SMTP_USER));
    await receive();

    await send(btoa(GMAIL_APP_PASSWORD));
    const authRes = await receive();
    if (!authRes.startsWith('235')) {
      throw new Error('SMTP Authentication failed: ' + authRes);
    }

    // MAIL FROM
    await send(`MAIL FROM:<${EMAIL_SENDER}>`);
    await receive();

    // RCPT TO
    await send(`RCPT TO:<${to}>`);
    await receive();

    // DATA
    await send('DATA');
    await receive();

    const date = new Date().toUTCString();
    const contentType = html ? 'text/html' : 'text/plain';
    const body = html || text;

    // Build formal MIME message
    const message = [
      `Date: ${date}`,
      `From: Aliolo <${EMAIL_SENDER}>`,
      `To: ${to}`,
      `Subject: ${subject}`,
      'MIME-Version: 1.0',
      `Content-Type: ${contentType}; charset=utf-8`,
      'Content-Transfer-Encoding: 7bit',
      '',
      body,
      '.',
    ].join('\r\n');

    await send(message);
    await receive();

    // QUIT
    await send('QUIT');
    await socket.close();
  } catch (e) {
    console.error('SMTP Error:', e);
    throw e;
  }
}
