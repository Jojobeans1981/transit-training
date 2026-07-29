const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';
const GROQ_MODEL = 'llama-3.1-8b-instant';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  let trainingContent, systemPrompt, industryName, type;
  try {
    ({ trainingContent, systemPrompt, industryName, type } = req.body);
  } catch (parseError) {
    return res.status(400).json({ error: 'Invalid JSON body' });
  }

  if (!trainingContent || !systemPrompt || !industryName || !type) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  if (!['quiz', 'study_guide', 'scenario'].includes(type)) {
    return res.status(400).json({ error: 'Invalid material type' });
  }

  if (!process.env.GROQ_API_KEY) {
    return res.status(500).json({ error: 'GROQ_API_KEY is not set' });
  }

  let prompt;
  if (type === 'quiz') {
    prompt = `You are an expert training material generator for the ${industryName} industry.
System context: ${systemPrompt}
Based on the following training material, generate a quiz with 5 multiple-choice questions.
Training Material:
${trainingContent}
Return ONLY a JSON object, no markdown, no code blocks:
{
  "quiz": [
    {"id": 1, "question": "...", "options": ["A", "B", "C", "D"], "correct_answer": "A", "explanation": "..."}
  ]
}`;
  } else if (type === 'study_guide') {
    prompt = `You are an expert training material generator for the ${industryName} industry.
System context: ${systemPrompt}
Based on the following training material, create a comprehensive study guide.
Training Material:
${trainingContent}
Return ONLY a JSON object, no markdown, no code blocks:
{
  "guide": {
    "title": "Study Guide: ${industryName}",
    "sections": [{"heading": "...", "content": "..."}],
    "key_takeaways": ["..."]
  }
}`;
  } else {
    prompt = `You are an expert training material generator for the ${industryName} industry.
System context: ${systemPrompt}
Based on the following training material, create a realistic scenario-based training exercise.
Training Material:
${trainingContent}
Return ONLY a JSON object, no markdown, no code blocks:
{
  "scenario": {
    "title": "...",
    "description": "...",
    "situation": "...",
    "questions": [{"id": 1, "prompt": "...", "expected_response": "..."}]
  }
}`;
  }

  try {
    const groqResponse = await fetch(GROQ_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: GROQ_MODEL,
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.3,
      }),
    });

    if (!groqResponse.ok) {
      const errorBody = await groqResponse.text();
      throw new Error(`Groq API error (${groqResponse.status}): ${errorBody}`);
    }

    const data = await groqResponse.json();
    const content = data.choices?.[0]?.message?.content;

    if (!content) {
      throw new Error('Groq response contained no message content');
    }

    let jsonData;
    try {
      jsonData = JSON.parse(content);
    } catch (parseError) {
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        jsonData = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error('Could not parse Groq response as JSON');
      }
    }

    return res.status(200).json(jsonData);
  } catch (error) {
    console.error('Groq API error:', error);
    return res.status(500).json({
      error: error.message || 'Failed to generate material',
    });
  }
}
