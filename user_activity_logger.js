const fs = require('fs');
const path = require('path');

const LOG_FILE = path.join(__dirname, 'user_activity_logs.txt');

function logUserActivity({ ip, userId, agencyCode, agencyName, action, detail }) {
  const time = new Date().toISOString();
  const logLine = `[${time}] IP:${ip} USER:${userId || ''} AGENCY_CODE:${agencyCode || ''} AGENCY_NAME:${agencyName || ''} ACTION:${action || ''} DETAIL:${detail || ''}\n`;
  fs.appendFile(LOG_FILE, logLine, err => {
    if (err) console.error('User activity log error:', err);
  });
}

module.exports = { logUserActivity }; 