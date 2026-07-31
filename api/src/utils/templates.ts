export function getVerificationEmail(code: string): string {
  return `<!DOCTYPE html>
  <html>
  <head>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@500;600&family=Roboto:wght@400;500&display=swap" rel="stylesheet">
  </head>
  <body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: 'Roboto', 'Segoe UI', Helvetica, Arial, sans-serif;">
    <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #F1F5F9; padding: 40px 20px;">
      <tr><td align="center">
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
          <tr><td style="padding: 40px 40px 20px 40px; text-align: center;">
            <h1 style="margin: 0; color: #1D4289; font-family: 'Poppins', sans-serif; font-size: 42px; font-weight: 500; letter-spacing: 4px; line-height: 1;">aliolo</h1>
            <p style="margin: 0; color: #64748B; font-family: 'Roboto', sans-serif; font-size: 14px; font-weight: 400;">Learn Visually. Master Permanently.</p>
          </td></tr>
          <tr><td style="padding: 20px 40px; color: #333C4E; line-height: 1.6;">
            <h2 style="margin: 0 0 15px 0; font-family: 'Poppins', sans-serif; font-size: 22px; font-weight: 600; text-align: center;">Confirm Registration</h2>
            <p style="margin: 0 0 20px 0; font-size: 16px; text-align: center;">Welcome to Aliolo! Please use the verification code below to activate your account and start building your visual library.</p>
            <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin: 30px 0;">
              <tr><td align="center">
                <div style="background-color: #F8FAFC; color: #1D4289; padding: 20px; border-radius: 12px; font-weight: bold; font-size: 32px; display: inline-block; font-family: 'Poppins', sans-serif; letter-spacing: 8px; border: 2px dashed #E2E8F0;">
                  ${code}
                </div>
              </td></tr>
            </table>
            <p style="margin: 0; font-size: 14px; color: #94A3B8; text-align: center;">This code will expire in 15 minutes.</p>
          </td></tr>
          <tr><td style="padding: 40px; text-align: center; border-top: 1px solid #E2E8F0; background-color: #F8FAFC;">
            <p style="margin: 0; font-size: 12px; color: #94A3B8;">&copy; 2026 Aliolo. All rights reserved.</p>
          </td></tr>
        </table>
      </td></tr>
    </table>
  </body>
  </html>`;
}

export function getResetPasswordEmail(code: string): string {
  return `<!DOCTYPE html>
  <html>
  <head>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@500;600&family=Roboto:wght@400;500&display=swap" rel="stylesheet">
  </head>
  <body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: 'Roboto', 'Segoe UI', Helvetica, Arial, sans-serif;">
    <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #F1F5F9; padding: 40px 20px;">
      <tr>
        <td align="center">
          <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
            <tr>
              <td style="padding: 40px 40px 20px 40px; text-align: center;">
                <h1 style="margin: 0; color: #1D4289; font-family: 'Poppins', sans-serif; font-size: 42px; font-weight: 500; letter-spacing: 4px; line-height: 1;">aliolo</h1>
                <p style="margin: 0; color: #64748B; font-family: 'Roboto', sans-serif; font-size: 14px; font-weight: 400;">Learn Visually. Master Permanently.</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 20px 40px; color: #333C4E; line-height: 1.6;">
                <h2 style="margin: 0 0 15px 0; font-family: 'Poppins', sans-serif; font-size: 22px; font-weight: 600; text-align: center;">Reset your password</h2>
                <p style="margin: 0 0 20px 0; font-size: 16px; text-align: center;">Forgot your password? It happens! Use the reset code below to choose a new one and get back to your learning.</p>
                <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin: 30px 0;">
                  <tr>
                    <td align="center">
                      <div style="background-color: #F8FAFC; color: #1D4289; padding: 20px; border-radius: 12px; font-weight: bold; font-size: 32px; display: inline-block; font-family: 'Poppins', sans-serif; letter-spacing: 8px; border: 2px dashed #E2E8F0;">
                        ${code}
                      </div>
                    </td>
                  </tr>
                </table>
                <p style="margin: 0; font-size: 14px; color: #94A3B8; text-align: center;">If you didn't request a password reset, you can safely ignore this email.</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 40px; text-align: center; border-top: 1px solid #E2E8F0; background-color: #F8FAFC;">
                <p style="margin: 0; font-size: 12px; color: #94A3B8;">&copy; 2026 Aliolo. All rights reserved.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
  </html>`;
}

export function getPasswordChangedEmail(email: string): string {
  return `<!DOCTYPE html>
  <html>
  <head>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@500;600&family=Roboto:wght@400;500&display=swap" rel="stylesheet">
  </head>
  <body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: 'Roboto', 'Segoe UI', Helvetica, Arial, sans-serif;">
    <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #F1F5F9; padding: 40px 20px;">
      <tr>
        <td align="center">
          <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
            <tr>
              <td style="padding: 40px 40px 20px 40px; text-align: center;">
                <h1 style="margin: 0; color: #1D4289; font-family: 'Poppins', sans-serif; font-size: 42px; font-weight: 500; letter-spacing: 4px; line-height: 1;">aliolo</h1>
                <p style="margin: 0; color: #64748B; font-family: 'Roboto', sans-serif; font-size: 14px; font-weight: 400;">Learn Visually. Master Permanently.</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 20px 40px; color: #333C4E; line-height: 1.6;">
                <h2 style="margin: 0 0 15px 0; font-family: 'Poppins', sans-serif; font-size: 22px; font-weight: 600;">Password Changed</h2>
                <p style="margin: 0 0 20px 0; font-size: 16px;">This email is to confirm that the password for your account <strong>${email}</strong> was recently updated.</p>
                <div style="background-color: #FFFBEB; border: 1px solid #FEF3C7; border-radius: 12px; padding: 20px; margin: 25px 0;">
                  <p style="margin: 0; font-size: 15px; color: #92400E; font-weight: 500;">Didn't make this change?</p>
                  <p style="margin: 8px 0 0 0; font-size: 14px; color: #B45309;">If you did not change your password, your account may have been compromised. Please reset your password immediately or contact our support team.</p>
                </div>
                <p style="margin: 30px 0 0 0; font-size: 14px; color: #94A3B8;">For your security, we recommend using a unique password that you don't use on other websites.</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 40px; text-align: center; border-top: 1px solid #E2E8F0; background-color: #F8FAFC;">
                <p style="margin: 0; font-size: 12px; color: #94A3B8;">&copy; 2026 Aliolo. All rights reserved.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
  </html>`;
}

export function getEmailChangeVerificationEmail(oldEmail: string, newEmail: string, code: string): string {
  return `<!DOCTYPE html>
  <html>
  <head>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@500;600&family=Roboto:wght@400;500&display=swap" rel="stylesheet">
  </head>
  <body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: 'Roboto', 'Segoe UI', Helvetica, Arial, sans-serif;">
    <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #F1F5F9; padding: 40px 20px;">
      <tr>
        <td align="center">
          <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
            <tr>
              <td style="padding: 40px 40px 20px 40px; text-align: center;">
                <h1 style="margin: 0; color: #1D4289; font-family: 'Poppins', sans-serif; font-size: 42px; font-weight: 500; letter-spacing: 4px; line-height: 1;">aliolo</h1>
                <p style="margin: 0; color: #64748B; font-family: 'Roboto', sans-serif; font-size: 14px; font-weight: 400;">Learn Visually. Master Permanently.</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 20px 40px; color: #333C4E; line-height: 1.6;">
                <h2 style="margin: 0 0 15px 0; font-family: 'Poppins', sans-serif; font-size: 22px; font-weight: 600; text-align: center;">Confirm Email Change</h2>
                <p style="margin: 0 0 10px 0; font-size: 16px; text-align: center;">We received a request to change the email address associated with your <strong>aliolo</strong> account.</p>
                <div style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 8px; padding: 15px; margin: 20px 0;">
                  <p style="margin: 0; font-size: 14px; color: #64748B;">Old Email: <span style="color: #333C4E; font-weight: 500;">${oldEmail}</span></p>
                  <p style="margin: 5px 0 0 0; font-size: 14px; color: #64748B;">New Email: <span style="color: #1D4289; font-weight: bold;">${newEmail}</span></p>
                </div>
                <p style="margin: 0 0 20px 0; font-size: 16px; text-align: center;">Please use the verification code below to confirm this new email address.</p>
                <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin: 30px 0;">
                  <tr>
                    <td align="center">
                      <div style="background-color: #F8FAFC; color: #1D4289; padding: 20px; border-radius: 12px; font-weight: bold; font-size: 32px; display: inline-block; font-family: 'Poppins', sans-serif; letter-spacing: 8px; border: 2px dashed #E2E8F0;">
                        ${code}
                      </div>
                    </td>
                  </tr>
                </table>
                <p style="margin: 0; font-size: 14px; color: #94A3B8; text-align: center;">If you did not request this change, you can safely ignore this email.</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 40px; text-align: center; border-top: 1px solid #E2E8F0; background-color: #F8FAFC;">
                <p style="margin: 0; font-size: 12px; color: #94A3B8;">&copy; 2026 Aliolo. All rights reserved.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
  </html>`;
}

export function getEmailChangedNotificationEmail(oldEmail: string, newEmail: string): string {
  return `<!DOCTYPE html>
  <html>
  <head>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@500;600&family=Roboto:wght@400;500&display=swap" rel="stylesheet">
  </head>
  <body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: 'Roboto', 'Segoe UI', Helvetica, Arial, sans-serif;">
    <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #F1F5F9; padding: 40px 20px;">
      <tr>
        <td align="center">
          <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
            <tr>
              <td style="padding: 40px 40px 20px 40px; text-align: center;">
                <h1 style="margin: 0; color: #1D4289; font-family: 'Poppins', sans-serif; font-size: 42px; font-weight: 500; letter-spacing: 4px; line-height: 1;">aliolo</h1>
                <p style="margin: 0; color: #64748B; font-family: 'Roboto', sans-serif; font-size: 14px; font-weight: 400;">Learn Visually. Master Permanently.</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 20px 40px; color: #333C4E; line-height: 1.6;">
                <h2 style="margin: 0 0 15px 0; font-family: 'Poppins', sans-serif; font-size: 22px; font-weight: 600;">Email Address Updated</h2>
                <p style="margin: 0 0 20px 0; font-size: 16px;">The primary email address for your <strong>aliolo</strong> account has been successfully changed.</p>
                <div style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; padding: 20px; margin: 25px 0;">
                  <p style="margin: 0; font-size: 14px; color: #64748B;">Previous Email: <span style="color: #333C4E; font-weight: 500; text-decoration: line-through;">${oldEmail}</span></p>
                  <p style="margin: 8px 0 0 0; font-size: 14px; color: #64748B;">New Email: <span style="color: #1D4289; font-weight: bold;">${newEmail}</span></p>
                </div>
                <div style="background-color: #FFFBEB; border: 1px solid #FEF3C7; border-radius: 12px; padding: 20px; margin: 25px 0;">
                  <p style="margin: 0; font-size: 15px; color: #92400E; font-weight: 500;">Didn't request this change?</p>
                  <p style="margin: 8px 0 0 0; font-size: 14px; color: #B45309;">If you did not authorize this update, please contact our support team immediately to secure your account. Your previous email address will no longer be used for sign-in or notifications.</p>
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding: 40px; text-align: center; border-top: 1px solid #E2E8F0; background-color: #F8FAFC;">
                <p style="margin: 0; font-size: 12px; color: #94A3B8;">&copy; 2026 Aliolo. All rights reserved.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
  </html>`;
}

export function getUserInvitationEmail(url: string): string {
  return `<!DOCTYPE html>
  <html>
  <head>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@500;600&family=Roboto:wght@400;500&display=swap" rel="stylesheet">
  </head>
  <body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: 'Roboto', 'Segoe UI', Helvetica, Arial, sans-serif;">
    <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #F1F5F9; padding: 40px 20px;">
      <tr>
        <td align="center">
          <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
            <tr>
              <td style="padding: 40px 40px 20px 40px; text-align: center;">
                <h1 style="margin: 0; color: #1D4289; font-family: 'Poppins', sans-serif; font-size: 42px; font-weight: 500; letter-spacing: 4px; line-height: 1;">aliolo</h1>
                <p style="margin: 0; color: #64748B; font-family: 'Roboto', sans-serif; font-size: 14px; font-weight: 400;">Learn Visually. Master Permanently.</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 20px 40px; color: #333C4E; line-height: 1.6;">
                <h2 style="margin: 0 0 15px 0; font-family: 'Poppins', sans-serif; font-size: 22px; font-weight: 600;">You've been invited!</h2>
                <p style="margin: 0 0 20px 0; font-size: 16px;">Hello! You have been invited to join <strong>aliolo</strong>, a visual learning platform designed to help you master subjects through science-backed algorithms.</p>
                <p style="margin: 0 0 20px 0; font-size: 16px;">Accept this invitation to set up your account and start your learning journey.</p>
                <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin: 30px 0;">
                  <tr>
                    <td align="center">
                      <a href="${url}" style="background-color: #1D4289; color: #ffffff; padding: 16px 32px; text-decoration: none; border-radius: 12px; font-weight: bold; font-size: 16px; display: inline-block; font-family: 'Poppins', sans-serif;">Accept Invitation</a>
                    </td>
                  </tr>
                </table>
                <p style="margin: 0; font-size: 14px; color: #94A3B8;">If you weren't expecting this invitation, you can safely ignore this email.</p>
                <p style="margin: 10px 0 0 0; font-size: 12px; color: #1C6887; word-break: break-all;">${url}</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 40px; text-align: center; border-top: 1px solid #E2E8F0; background-color: #F8FAFC;">
                <p style="margin: 0; font-size: 12px; color: #94A3B8;">&copy; 2026 Aliolo. All rights reserved.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
  </html>`;
}

export function getWelcomeEmail(username: string): string {
  return `<!DOCTYPE html>
  <html>
  <head>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@500;600&family=Roboto:wght@400;500&display=swap" rel="stylesheet">
  </head>
  <body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: 'Roboto', 'Segoe UI', Helvetica, Arial, sans-serif;">
    <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #F1F5F9; padding: 40px 20px;">
      <tr>
        <td align="center">
          <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
            <tr>
              <td style="padding: 40px 40px 20px 40px; text-align: center;">
                <h1 style="margin: 0; color: #1D4289; font-family: 'Poppins', sans-serif; font-size: 42px; font-weight: 500; letter-spacing: 4px; line-height: 1;">aliolo</h1>
                <p style="margin: 0; color: #64748B; font-family: 'Roboto', sans-serif; font-size: 14px; font-weight: 400;">Learn Visually. Master Permanently.</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 20px 40px; color: #333C4E; line-height: 1.6;">
                <h2 style="margin: 0 0 15px 0; font-family: 'Poppins', sans-serif; font-size: 22px; font-weight: 600;">Welcome to Aliolo, ${username}!</h2>
                <p style="margin: 0; font-size: 16px;">We're thrilled to have you join our community! Aliolo is designed to help you learn and master any subject through the power of visual flashcards and science-backed spaced repetition.</p>
                <p style="margin: 20px 0; font-size: 16px;">Your account is now active and you're ready to start building your knowledge. Explore our diverse learning pillars, create your own decks, or join subjects shared by others.</p>
                <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin: 30px 0;">
                  <tr>
                    <td align="center">
                      <a href="https://aliolo.com" style="background-color: #1D4289; color: #ffffff; padding: 16px 32px; text-decoration: none; border-radius: 12px; font-weight: bold; font-size: 16px; display: inline-block; font-family: 'Poppins', sans-serif;">Go to Dashboard</a>
                    </td>
                  </tr>
                </table>
                <p style="margin: 0; font-size: 14px; color: #94A3B8;">Happy learning!</p>
                <p style="margin: 5px 0 0 0; font-size: 14px; color: #1D4289; font-weight: 500;">The Aliolo Team</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 40px; text-align: center; border-top: 1px solid #E2E8F0; background-color: #F8FAFC;">
                <p style="margin: 0; font-size: 12px; color: #94A3B8;">&copy; 2026 Aliolo. All rights reserved.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
  </html>`;
}

export function getAccountDeletedEmail(username: string): string {
  return `<!DOCTYPE html>
  <html>
  <head>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@500;600&family=Roboto:wght@400;500&display=swap" rel="stylesheet">
  </head>
  <body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: 'Roboto', 'Segoe UI', Helvetica, Arial, sans-serif;">
    <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #F1F5F9; padding: 40px 20px;">
      <tr>
        <td align="center">
          <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
            <tr>
              <td style="padding: 40px 40px 20px 40px; text-align: center;">
                <h1 style="margin: 0; color: #1D4289; font-family: 'Poppins', sans-serif; font-size: 42px; font-weight: 500; letter-spacing: 4px; line-height: 1;">aliolo</h1>
                <p style="margin: 0; color: #64748B; font-family: 'Roboto', sans-serif; font-size: 14px; font-weight: 400;">Learn Visually. Master Permanently.</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 20px 40px; color: #333C4E; line-height: 1.6;">
                <h2 style="margin: 0 0 15px 0; font-family: 'Poppins', sans-serif; font-size: 22px; font-weight: 600;">Account Deleted</h2>
                <p style="margin: 0 0 20px 0; font-size: 16px;">Hello ${username},</p>
                <p style="margin: 0 0 20px 0; font-size: 16px;">This email is to confirm that your <strong>aliolo</strong> account and all associated data have been successfully deleted as per your request.</p>
                <p style="margin: 0 0 20px 0; font-size: 16px;">We're sorry to see you go, but we respect your decision. Thank you for being a part of our community. If you ever decide to come back, you'll always be welcome to start a new learning journey with us.</p>
                <div style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; padding: 20px; margin: 25px 0;">
                  <p style="margin: 0; font-size: 14px; color: #64748B; font-style: italic;">Note: Your data has been permanently removed and cannot be recovered.</p>
                </div>
                <p style="margin: 0; font-size: 14px; color: #94A3B8;">Best regards,</p>
                <p style="margin: 5px 0 0 0; font-size: 14px; color: #1D4289; font-weight: 500;">The Aliolo Team</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 40px; text-align: center; border-top: 1px solid #E2E8F0; background-color: #F8FAFC;">
                <p style="margin: 0; font-size: 12px; color: #94A3B8;">&copy; 2026 Aliolo. All rights reserved.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
  </html>`;
}
