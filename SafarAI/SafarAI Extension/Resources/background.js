console.log('SafarAI background script loaded');

// Message handler
browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log('Background received message:', request);

    if (request.action === 'chat') {
        handleChatRequest(request, sender)
            .then(response => sendResponse(response))
            .catch(error => sendResponse({ error: error.message }));
        return true; // Keep the message channel open for async response
    }

    return false;
});

// Handle chat request
async function handleChatRequest(request, sender) {
    const { messages, apiKey } = request;

    if (!apiKey) {
        throw new Error('API key not provided');
    }

    if (!messages || messages.length === 0) {
        throw new Error('No messages provided');
    }

    try {
        // Call OpenAI API
        const response = await callOpenAI(apiKey, messages);
        return { success: true, message: response };
    } catch (error) {
        console.error('Error calling OpenAI API:', error);
        throw error;
    }
}

// Call OpenAI API
async function callOpenAI(apiKey, messages) {
    const url = 'https://api.openai.com/v1/chat/completions';

    // Format messages for OpenAI API
    const formattedMessages = messages.map(msg => ({
        role: msg.role === 'assistant' ? 'assistant' : 'user',
        content: msg.content
    }));

    const requestBody = {
        model: 'gpt-3.5-turbo',
        messages: formattedMessages,
        temperature: 0.7,
        max_tokens: 1000
    };

    console.log('Calling OpenAI API with:', requestBody);

    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${apiKey}`
        },
        body: JSON.stringify(requestBody)
    });

    if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        console.error('OpenAI API error:', errorData);

        if (response.status === 401) {
            throw new Error('Invalid API key. Please check your OpenAI API key in settings.');
        } else if (response.status === 429) {
            throw new Error('Rate limit exceeded. Please try again later.');
        } else if (response.status === 500) {
            throw new Error('OpenAI service error. Please try again later.');
        } else {
            throw new Error(errorData.error?.message || `API error: ${response.status}`);
        }
    }

    const data = await response.json();
    console.log('OpenAI API response:', data);

    if (!data.choices || data.choices.length === 0) {
        throw new Error('No response from OpenAI');
    }

    return data.choices[0].message.content;
}
