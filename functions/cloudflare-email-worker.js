// Cloudflare Worker for sending emails via MailChannels (FREE)
// Deploy this as a Cloudflare Worker and call it from Firebase Functions

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    // Verify the request is from your Firebase Functions (add your own auth)
    const authHeader = request.headers.get('Authorization');
    if (authHeader !== `Bearer ${env.EMAIL_API_KEY}`) {
      return new Response('Unauthorized', { status: 401 });
    }

    const { to, subject, html, text } = await request.json();

    const send_request = new Request('https://api.mailchannels.net/tx/v1/send', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        personalizations: [
          {
            to: [{ email: to }],
          },
        ],
        from: {
          email: 'noreply@fermi-plus.com',
          name: 'Fermi Education Platform',
        },
        subject: subject,
        content: [
          {
            type: 'text/plain',
            value: text,
          },
          {
            type: 'text/html',
            value: html,
          },
        ],
      }),
    });

    const response = await fetch(send_request);
    
    if (response.ok) {
      return new Response('Email sent successfully', { status: 200 });
    } else {
      return new Response(`Email failed: ${await response.text()}`, { 
        status: response.status 
      });
    }
  },
};

// Environment variables to set in Cloudflare:
// EMAIL_API_KEY: A secret key you generate to authenticate requests