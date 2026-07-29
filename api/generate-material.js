import Anthropic from '@anthropic-ai/sdk';

const client = new Anthropic({
  apiKey: process.env.CLAUDE_API_KEY,
});

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { trainingContent, systemPrompt, industryName, type } = req.body;

  if (!trainingContent || !systemPrompt || !industryName || !type) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  if (!['quiz', 'study_guide', 'scenario'].includes(type)) {
    return res.status(400).json({ error: 'Invalid material type' });
  }

  try {
    let prompt;

    if (type === 'quiz') {
      prompt = `You are an expert training material generator for the ${industryName} industry.
System context: ${systemPrompt}
Based on the following training material, generate a quiz with 5 multiple-choice questions.
Training Material:
${trainingContent}
Return ONLY a JSON object:
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
Return ONLY a JSON object:
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
Return ONLY a JSON object:
{
  "scenario": {
    "title": "...",
    "description": "...",
    "situation": "...",
    "questions": [{"id": 1, "prompt": "...", "expected_response": "..."}]
  }
}`;
    }

    const message = await client.messages.create({
      model: 'claude-opus-4-1',
      max_tokens: 2048,
      messages: [
        {
          role: 'user',
          content: prompt,
        },
      ],
    });

    const content = message.content[0].text;
    let jsonData;

    try {
      jsonData = JSON.parse(content);
    } catch (parseError) {
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        jsonData = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error('Could not parse Claude response as JSON');
      }
    }

    return res.status(200).json(jsonData);
  } catch (error) {
    console.error('Claude API error:', error);
    return res.status(500).json({
      error: error.message || 'Failed to generate material',
    });
  }
}
