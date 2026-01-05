// SafarAI background script

// Native port connection
let nativePort = null;

// Establish connection to native app
function connectToNative() {
    try {
        nativePort = browser.runtime.connectNative("com.grtnr.SafarAI");

        nativePort.onMessage.addListener((message) => {
            handleNativeMessage(message);
        });

        nativePort.onDisconnect.addListener(() => {
            nativePort = null;
            setTimeout(connectToNative, 5000);
        });

        // Send ready signal
        browser.runtime.sendNativeMessage("com.grtnr.SafarAI", {
            action: "extensionReady",
            version: browser.runtime.getManifest().version
        });

    } catch (error) {
        console.error('Failed to connect:', error.message);
        setTimeout(connectToNative, 5000);
    }
}

// Send message to native app
function sendToNative(message) {
    try {
        browser.runtime.sendNativeMessage("com.grtnr.SafarAI", message);
    } catch (error) {
        console.error('Send failed:', error.message);
    }
}

// Handle messages from native app (via port)
function handleNativeMessage(message) {
    const data = message.userInfo || message;
    const action = data.action || message.name;

    switch (action) {
        case "getPageContent":
            getPageContent(data.tabId, data.options);
            break;
        case "ping":
            sendToNative({ action: "pong", timestamp: Date.now() });
            break;
    }
}

// Get page content from active or specific tab
async function getPageContent(tabId = null, options = {}) {
    try {
        let tab;
        if (tabId) {
            tab = await browser.tabs.get(tabId);
        } else {
            const tabs = await browser.tabs.query({ active: true, currentWindow: true });
            tab = tabs[0];
        }

        if (!tab) {
            throw new Error('No tab found');
        }

        const content = await browser.tabs.sendMessage(tab.id, {
            action: "getPageContent",
            options: options
        });

        if (!content) {
            throw new Error('Content script not responding');
        }

        console.log('📄', content.title);

        sendToNative({
            action: "pageContent",
            data: content,
            tabId: tab.id,
            timestamp: Date.now()
        });

    } catch (error) {
        console.error('Get page content:', error.message);
        sendToNative({
            action: "error",
            message: error.message,
            code: "GET_PAGE_CONTENT_FAILED"
        });
    }
}

// Listen for tab changes
browser.tabs.onActivated.addListener((activeInfo) => {
    sendToNative({
        action: "tabChanged",
        tabId: activeInfo.tabId
    });

    setTimeout(() => {
        getPageContent(activeInfo.tabId);
    }, 500);
});

// Listen for page loads
browser.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (changeInfo.status === 'complete') {
        sendToNative({
            action: "pageLoaded",
            tabId: tabId,
            url: tab.url,
            title: tab.title
        });

        setTimeout(() => {
            getPageContent(tabId);
        }, 500);
    }
});

// Legacy: Handle messages from popup (if popup is still used)
browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log('Background received message:', request);

    if (request.action === 'chat') {
        // Legacy popup support - will be removed later
        handleChatRequest(request, sender)
            .then(response => sendResponse(response))
            .catch(error => sendResponse({ error: error.message }));
        return true;
    }

    return false;
});

// Legacy chat handler (for popup compatibility)
async function handleChatRequest(request, sender) {
    const { messages, apiKey } = request;

    if (!apiKey) {
        throw new Error('API key not provided');
    }

    if (!messages || messages.length === 0) {
        throw new Error('No messages provided');
    }

    try {
        const response = await callOpenAI(apiKey, messages);
        return { success: true, message: response };
    } catch (error) {
        console.error('Error calling OpenAI API:', error);
        throw error;
    }
}

// Legacy OpenAI API call (for popup compatibility)
async function callOpenAI(apiKey, messages) {
    const url = 'https://api.openai.com/v1/chat/completions';

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

    if (!data.choices || data.choices.length === 0) {
        throw new Error('No response from OpenAI');
    }

    return data.choices[0].message.content;
}

// Connect to native app on startup
connectToNative();
