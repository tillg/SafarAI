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

// State
let messages = [];
let apiKey = '';

// Initialize
async function init() {
    console.log('SafarAI popup initialized');

    // Load API key from storage
    await loadApiKey();

    // Check if API key is set
    if (!apiKey) {
        showEmptyState('🔑', 'Please set your OpenAI API key in settings to get started.');
    } else {
        showEmptyState('💬', 'Start a conversation! Type a message below.');
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
    addMessage('assistant', 'Thinking...');

    // TODO: In Phase 2, we'll implement actual API call
    // For now, just show a placeholder response
    setTimeout(() => {
        // Remove "Thinking..." message
        const lastMessage = messagesContainer.lastElementChild;
        if (lastMessage && lastMessage.querySelector('.message-content').textContent === 'Thinking...') {
            lastMessage.remove();
            messages.pop();
        }

        // Add mock response
        addMessage('assistant', 'This is a placeholder response. In Phase 2, we\'ll connect to the OpenAI API to generate real responses!');

        // Re-enable input
        messageInput.disabled = false;
        sendBtn.disabled = false;
        messageInput.focus();
    }, 1000);
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
