const express = require('express');
const path = require('path');

const app = express();

const API_PORT = Number(process.env.API_PORT || 8000);
const API_SERVICE_NAME = process.env.API_SERVICE_NAME || 'localhost';
const API_URL = process.env.API_URL || `http://${API_SERVICE_NAME}:${API_PORT}`;
const FRONTEND_PORT = Number(process.env.FRONTEND_PORT || 5000);
const API_TIMEOUT = Number(process.env.API_TIMEOUT || 5000);

async function apiRequest(pathname, options = {}) {
  const response = await fetch(`${API_URL}${pathname}`, {
    ...options,
    signal: AbortSignal.timeout(API_TIMEOUT),
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });

  let payload;
  try {
    payload = await response.json();
  } catch {
    payload = null;
  }

  if (!response.ok) {
    const error = new Error(payload?.detail || payload?.error || `Request failed with status ${response.status}`);
    error.statusCode = response.status;
    throw error;
  }

  return payload;
}

function getErrorMessage(err) {
  return err.message || 'Request failed';
}

app.use(express.json());
app.use(express.static(path.join(__dirname, 'views')));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.post('/submit', async (req, res) => {
  try {
    const data = await apiRequest('/jobs', { method: 'POST' });
    res.json(data);
  } catch (err) {
    res.status(502).json({ error: getErrorMessage(err) });
  }
});

app.get('/status/:id', async (req, res) => {
  try {
    const data = await apiRequest(`/jobs/${req.params.id}`);
    res.json(data);
  } catch (err) {
    const statusCode = err.statusCode || 502;
    res.status(statusCode).json({ error: getErrorMessage(err) });
  }
});

app.listen(FRONTEND_PORT, () => {
  console.log(`Frontend running on port ${FRONTEND_PORT}`);
});
