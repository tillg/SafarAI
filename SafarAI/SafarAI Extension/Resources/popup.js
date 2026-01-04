// DOM Elements
const settingsBtn = document.getElementById('settings-btn');
const settingsPanel = document.getElementById('settings-panel');
const saveSettingsBtn = document.getElementById('save-settings-btn');
const cancelSettingsBtn = document.getElementById('cancel-settings-btn');
const apiKeyInput = document.getElementById('api-key');
const messagesContainer = document.getElementById('messages');
const messageInput = document.getElementById('message-input');
const sendBtn = document.getElementById('send-btn');
const chatView = document.getElementById('chat-view');
const includePageBtn = document.getElementById('include-page-btn');
const pageContextBanner = document.getElementById('page-context-banner');
const pageContextTitle = document.getElementById('page-context-title');
const removeContextBtn = document.getElementById('remove-context-btn');

// State
let messages = [];
let apiKey = '';
let pageContent = null;

// Initialize
async function init() {
    console.log('SafarAI popup initialized');

    // Load API key from storage
    await loadApiKey();

    // Auto-load page content by default
    await loadPageContent();

    // Check if API key is set
    if (!apiKey) {
        showEmptyState('🔑', 'Please set your OpenAI API key in settings to get started.');
    } else {
        if (pageContent) {
            showEmptyState('💬', `Ask me anything about: ${pageContent.title}`);
        } else {
            showEmptyState('💬', 'Start a conversation! Type a message below.');
        }
    }

    // Setup event listeners
    setupEventListeners();
}

// Load API key from storage
async function loadApiKey() {
    try {
        const result = await browser.storage.sync.get('apiKey');
        apiKey = result.apiKey || '';
        if (apiKey) {
            apiKeyInput.value = apiKey;
        }
    } catch (error) {
        console.error('Error loading API key:', error);
    }
}

// Save API key to storage
async function saveApiKey(key) {
    try {
        await browser.storage.sync.set({ apiKey: key });
        apiKey = key;
        console.log('API key saved');
        return true;
    } catch (error) {
        console.error('Error saving API key:', error);
        return false;
    }
}

// Setup event listeners
function setupEventListeners() {
    // Settings button
    settingsBtn.addEventListener('click', toggleSettings);

    // Save settings
    saveSettingsBtn.addEventListener('click', async () => {
        const key = apiKeyInput.value.trim();
        if (key) {
            const success = await saveApiKey(key);
            if (success) {
                toggleSettings();
                if (messages.length === 0) {
                    showEmptyState('💬', 'Start a conversation! Type a message below.');
                }
            }
        } else {
            alert('Please enter an API key');
        }
    });

    // Cancel settings
    cancelSettingsBtn.addEventListener('click', () => {
        apiKeyInput.value = apiKey; // Reset to saved value
        toggleSettings();
    });

    // Send message button
    sendBtn.addEventListener('click', handleSendMessage);

    // Enter key to send (Shift+Enter for new line)
    messageInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleSendMessage();
        }
    });

    // Auto-resize textarea
    messageInput.addEventListener('input', () => {
        messageInput.style.height = 'auto';
        messageInput.style.height = Math.min(messageInput.scrollHeight, 120) + 'px';
    });

    // Include page context button - now a toggle
    includePageBtn.addEventListener('click', togglePageContext);

    // Remove context button
    removeContextBtn.addEventListener('click', () => {
        pageContent = null;
        updatePageContextUI();
    });
}

// Toggle page context
function togglePageContext() {
    if (pageContent) {
        // Turn off - remove page content
        pageContent = null;
        updatePageContextUI();
    } else {
        // Turn on - load page content
        loadPageContent();
    }
}

// Toggle settings panel
function toggleSettings() {
    settingsPanel.classList.toggle('hidden');
}

// Show empty state
function showEmptyState(icon, text) {
    messagesContainer.innerHTML = `
        <div class="empty-state">
            <div class="empty-state-icon">${icon}</div>
            <div class="empty-state-text">${text}</div>
        </div>
    `;
}

// Add message to UI
function addMessage(role, content) {
    // Remove empty state if exists
    const emptyState = messagesContainer.querySelector('.empty-state');
    if (emptyState) {
        emptyState.remove();
    }

    // Create message element
    const messageEl = document.createElement('div');
    messageEl.className = `message ${role}`;

    const label = role === 'user' ? 'You' : 'AI';

    messageEl.innerHTML = `
        <div class="message-label">${label}</div>
        <div class="message-content">${escapeHtml(content)}</div>
    `;

    messagesContainer.appendChild(messageEl);

    // Scroll to bottom
    messagesContainer.scrollTop = messagesContainer.scrollHeight;

    // Add to messages array
    messages.push({ role, content });
}

// Load page content
async function loadPageContent() {
    try {
        // Get current tab
        const tabs = await browser.tabs.query({ active: true, currentWindow: true });
        if (!tabs || tabs.length === 0) {
            console.log('No active tab found');
            return;
        }

        const tab = tabs[0];

        // Check if we can access this page
        if (tab.url.startsWith('chrome://') || tab.url.startsWith('about:') || tab.url.startsWith('safari://')) {
            console.log('Cannot access browser internal pages');
            pageContent = null;
            updatePageContextUI();
            return;
        }

        // Request page content from content script
        console.log('Requesting page content from tab:', tab.id);
        pageContent = await browser.tabs.sendMessage(tab.id, { action: 'getPageContent' });

        console.log('Received page content:', pageContent);

        // Update UI
        updatePageContextUI();

    } catch (error) {
        console.error('Error getting page content:', error);
        // Don't show alert on auto-load, just fail silently
        pageContent = null;
        updatePageContextUI();
    }
}

// Update page context UI
function updatePageContextUI() {
    if (pageContent) {
        pageContextBanner.classList.remove('hidden');
        pageContextTitle.textContent = pageContent.title || pageContent.url;
        includePageBtn.classList.add('active');
        includePageBtn.title = 'Page content included (click to disable)';
    } else {
        pageContextBanner.classList.add('hidden');
        includePageBtn.classList.remove('active');
        includePageBtn.title = 'Page content not included (click to enable)';
    }
}

// Handle send message
async function handleSendMessage() {
    const message = messageInput.value.trim();

    if (!message) return;

    // Check if API key is set
    if (!apiKey) {
        alert('Please set your OpenAI API key in settings first.');
        toggleSettings();
        return;
    }

    // Add user message
    addMessage('user', message);

    // Clear input
    messageInput.value = '';
    messageInput.style.height = 'auto';

    // Disable input while processing
    messageInput.disabled = true;
    sendBtn.disabled = true;

    // Add loading message
    const loadingMessageIndex = messages.length;
    addMessage('assistant', 'Thinking...');

    try {
        // Prepare messages to send
        let messagesToSend = messages.slice(0, -1); // Exclude the "Thinking..." message

        // If page content is included and this is the first user message with context
        if (pageContent && messagesToSend.length > 0) {
            // Create a copy of messages
            messagesToSend = [...messagesToSend];

            // Get the last user message
            const lastUserMessageIndex = messagesToSend.length - 1;
            const lastUserMessage = messagesToSend[lastUserMessageIndex];

            // Prepend page content to the last user message
            const pageContextText = `[Page Context]\nTitle: ${pageContent.title}\nURL: ${pageContent.url}\n${pageContent.description ? 'Description: ' + pageContent.description + '\n' : ''}Content: ${pageContent.text}\n\n[User Question]\n${lastUserMessage.content}`;

            messagesToSend[lastUserMessageIndex] = {
                ...lastUserMessage,
                content: pageContextText
            };
        }

        // Send message to background script
        console.log('Sending message to background script...');
        const response = await browser.runtime.sendMessage({
            action: 'chat',
            messages: messagesToSend,
            apiKey: apiKey
        });

        console.log('Response from background:', response);

        // Remove "Thinking..." message
        const lastMessage = messagesContainer.lastElementChild;
        if (lastMessage && lastMessage.querySelector('.message-content').textContent === 'Thinking...') {
            lastMessage.remove();
            messages.pop();
        }

        // Check for error
        if (response.error) {
            throw new Error(response.error);
        }

        // Add AI response
        if (response.success && response.message) {
            addMessage('assistant', response.message);
            // Note: Page content remains loaded for follow-up questions
        } else {
            throw new Error('Invalid response from API');
        }

    } catch (error) {
        console.error('Error sending message:', error);

        // Remove "Thinking..." message
        const lastMessage = messagesContainer.lastElementChild;
        if (lastMessage && lastMessage.querySelector('.message-content').textContent === 'Thinking...') {
            lastMessage.remove();
            messages.pop();
        }

        // Show error message
        addMessage('assistant', `❌ Error: ${error.message}`);
    } finally {
        // Re-enable input
        messageInput.disabled = false;
        sendBtn.disabled = false;
        messageInput.focus();
    }
}

// Utility: Escape HTML
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
