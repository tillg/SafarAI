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
        console.log('📤 Sending to native:', message.action);
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
        case "openTab":
            if (data.url) {
                browser.tabs.create({ url: data.url });
            }
            break;
    }
}

// Check if content script is available
async function isContentScriptReady(tabId) {
    try {
        // Try to send a message and wait for response
        const response = await Promise.race([
            browser.tabs.sendMessage(tabId, { action: "ping" }),
            new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 1000))
        ]);

        console.log('🏓 Ping response from tab', tabId, ':', response);

        // Check if we got a valid response
        if (response && typeof response === 'object' && response.ready === true) {
            return true;
        }

        console.log('⚠️ Invalid ping response:', response);
        return false;
    } catch (error) {
        console.log('❌ Ping failed for tab', tabId, ':', error.message);
        return false;
    }
}

// Track which tabs we've successfully extracted content from
const contentExtractedTabs = new Set();

// Get page content from active or specific tab
async function getPageContent(tabId = null, options = {}, skipIfAlreadyExtracted = false) {
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

        // Skip if we already extracted content for this tab
        if (skipIfAlreadyExtracted && contentExtractedTabs.has(tab.id)) {
            console.log('✓ Already extracted content for tab', tab.id);
            return;
        }

        // Skip restricted pages where content scripts can't run
        if (!tab.url ||
            tab.url.startsWith('about:') ||
            tab.url.startsWith('chrome:') ||
            tab.url.startsWith('safari:') ||
            tab.url.startsWith('safari-extension:')) {
            console.log('⏭️ Skipping restricted page:', tab.url);
            return;
        }

        // Try to get content directly (skip ping check - Safari has messaging issues)
        const content = await browser.tabs.sendMessage(tab.id, {
            action: "getPageContent",
            options: options
        });

        if (!content) {
            throw new Error('Content script not responding');
        }

        console.log('📄', content.title);

        // Mark this tab as extracted
        contentExtractedTabs.add(tab.id);

        sendToNative({
            action: "pageContent",
            data: content,
            tabId: tab.id,
            timestamp: Date.now()
        });

    } catch (error) {
        // Content script not available or failed - this is normal for some pages
        console.log('⏭️ Could not get page content for tab', tabId, ':', error.message);
    }
}

// Clear content extraction tracking when tab is closed
browser.tabs.onRemoved.addListener((tabId) => {
    contentExtractedTabs.delete(tabId);
});

// Listen for tab changes
browser.tabs.onActivated.addListener(async (activeInfo) => {
    // Get tab info to include in event
    const tab = await browser.tabs.get(activeInfo.tabId);

    // Build details object without null values
    const details = {};
    if (activeInfo.previousTabId) {
        details.previousTabId = activeInfo.previousTabId.toString();
    }

    const event = {
        type: "tab_switch",
        timestamp: Date.now(),
        tabId: activeInfo.tabId,
        url: tab.url,
        title: tab.title,
        details: details
    };

    console.log('🔄 Tab switch event:', event);

    sendToNative({
        action: "browserEvent",
        event: event
    });

    // Delay page content fetch so browserEvent has time to be processed
    setTimeout(() => {
        // Legacy support - send old format
        sendToNative({
            action: "tabChanged",
            tabId: activeInfo.tabId
        });

        // Only try to get content if page is completely loaded
        if (tab.status === 'complete') {
            // Try with increasing delays, but skip if already extracted
            setTimeout(() => getPageContent(activeInfo.tabId, {}, true), 100);
            setTimeout(() => getPageContent(activeInfo.tabId, {}, true), 500);
            setTimeout(() => getPageContent(activeInfo.tabId, {}, true), 1000);
        } else {
            console.log('⏳ Tab still loading, will get content when complete');
        }
    }, 200);
});

// Listen for page loads
browser.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (changeInfo.status === 'complete') {
        console.log('🔗 Page load event:', { tabId, url: tab.url, title: tab.title });

        sendToNative({
            action: "browserEvent",
            event: {
                type: "page_load",
                timestamp: Date.now(),
                tabId: tabId,
                url: tab.url || "",
                title: tab.title || "",
                details: {}
            }
        });

        // Delay legacy messages so browserEvent has time to be processed
        setTimeout(() => {
            // Legacy support - send old format
            sendToNative({
                action: "pageLoaded",
                tabId: tabId,
                url: tab.url,
                title: tab.title
            });

            getPageContent(tabId);
        }, 200);
    }
});

// Listen for tab creation
browser.tabs.onCreated.addListener((tab) => {
    console.log('➕ Tab open event:', { tabId: tab.id, url: tab.url, title: tab.title });

    sendToNative({
        action: "browserEvent",
        event: {
            type: "tab_open",
            timestamp: Date.now(),
            tabId: tab.id,
            url: tab.url || tab.pendingUrl || "",
            title: tab.title || "New Tab",
            details: {}
        }
    });
});

// Listen for tab closure
browser.tabs.onRemoved.addListener((tabId, removeInfo) => {
    const details = {};
    if (removeInfo.isWindowClosing !== undefined) {
        details.windowClosing = removeInfo.isWindowClosing.toString();
    }

    console.log('➖ Tab close event:', { tabId, details });

    sendToNative({
        action: "browserEvent",
        event: {
            type: "tab_close",
            timestamp: Date.now(),
            tabId: tabId,
            url: "",
            title: "",
            details: details
        }
    });
});

// Handle messages from content scripts and popup
browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log('Background received message:', request);

    if (request.action === 'linkClicked') {
        // Forward link click event to native app
        sendToNative({
            action: "browserEvent",
            event: request.event
        });
        return false;
    }

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
