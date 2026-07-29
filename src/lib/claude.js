export const generateQuiz = async (trainingContent, systemPrompt, industryName) => {
  return await callBackend({
    trainingContent,
    systemPrompt,
    industryName,
    type: 'quiz'
  });
};

export const generateStudyGuide = async (trainingContent, systemPrompt, industryName) => {
  return await callBackend({
    trainingContent,
    systemPrompt,
    industryName,
    type: 'study_guide'
  });
};

export const generateScenario = async (trainingContent, systemPrompt, industryName) => {
  return await callBackend({
    trainingContent,
    systemPrompt,
    industryName,
    type: 'scenario'
  });
};

async function callBackend(payload) {
  try {
    const response = await fetch('/api/generate-material', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || `Backend error: ${response.statusText}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Backend error:', error);
    throw error;
  }
}
