import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { GoogleGenerativeAI } from "@google/generative-ai";

admin.initializeApp();

const genAI = new GoogleGenerativeAI("70k79qb7xr7spq7tvir7pxzxp8cs0aou");

export const healthChat = functions.https.onRequest(async (req, res) => {
  try {
    const { messages } = req.body;

    const prompt = messages.map((m: any) => `${m.role}: ${m.text}`).join("\n");

    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

    const result = await model.generateContent(prompt + "\nHealth Assistant:");

    const reply = result.response.text().trim();

    res.json({ reply });
  } catch (error) {
    console.error("Error generating Gemini response:", error);
    res.status(500).json({ error: "Gemini API error" });
  }
});
