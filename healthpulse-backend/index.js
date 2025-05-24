// index.js
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const { GoogleGenerativeAI } = require('@google/generative-ai');

dotenv.config(); // Load .env

const app = express();
app.use(cors());
app.use(express.json());

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

app.post('/healthChat', async (req, res) => {
  try {
    const messages = req.body.messages;
    if (!messages) {
      return res.status(400).json({ error: 'Messages are required' });
    }

    const model = genAI.getGenerativeModel({ model: "gemini-pro" });

    const chat = model.startChat({
      history: messages.map(m => ({
        role: m.role,
        parts: [{ text: m.content }]
      })),
    });

    const result = await chat.sendMessage(messages[messages.length - 1].content);
    const reply = result.response.text();

    res.json({ reply });
  } catch (error) {
    console.error('🔥 Error:', error.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`✅ HealthPulse Gemini backend running at http://localhost:${PORT}`);
});
