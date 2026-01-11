// Listen for requests from background script
browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log('Content script received:', request.action);

    if (request.action === 'ping') {
        // Respond to ping to indicate content script is ready
        const response = { ready: true };
        console.log('Sending ping response:', response);
        sendResponse(response);
        return true; // Keep channel open for async response
    }

    if (request.action === 'getPageContent') {
        try {
            const content = extractPageContent();
            console.log('📄', content.title);
            sendResponse(content);
        } catch (error) {
            console.error('Extract failed:', error.message);
            sendResponse(null);
        }
        return true;
    }

    return false;
});

// Log that content script loaded
console.log('✅ SafarAI content script loaded');

// Extract page content
function extractPageContent() {
    const content = {
        url: window.location.href,
        title: document.title,
        text: '',
        description: '',
        siteName: ''
    };

    // Get meta description
    const metaDescription = document.querySelector('meta[name="description"]');
    if (metaDescription) {
        content.description = metaDescription.getAttribute('content') || '';
    }

    // Get Open Graph site name
    const ogSiteName = document.querySelector('meta[property="og:site_name"]');
    if (ogSiteName) {
        content.siteName = ogSiteName.getAttribute('content') || '';
    }

    // Get main content text
    content.text = extractMainText();

    // Truncate text to reasonable length (10,000 chars ~ 2,500 tokens)
    if (content.text.length > 10000) {
        content.text = content.text.substring(0, 10000) + '...';
    }

    console.log('Extracted page content:', {
        url: content.url,
        title: content.title,
        textLength: content.text.length
    });

    return content;
}

// Extract main text content from the page
function extractMainText() {
    // Try to find main content areas
    const mainSelectors = [
        'main',
        'article',
        '[role="main"]',
        '.main-content',
        '#main-content',
        '.content',
        '#content',
        '.post-content',
        '.article-content'
    ];

    let mainElement = null;

    // Try to find main content container
    for (const selector of mainSelectors) {
        mainElement = document.querySelector(selector);
        if (mainElement) break;
    }

    // If no main content found, use body
    if (!mainElement) {
        mainElement = document.body;
    }

    // Extract text from the main element
    const text = extractTextFromElement(mainElement);

    return cleanText(text);
}

// Extract text from an element, ignoring script, style, and hidden elements
function extractTextFromElement(element) {
    const excludedTags = ['SCRIPT', 'STYLE', 'NOSCRIPT', 'IFRAME', 'SVG'];
    const textParts = [];

    function traverse(node) {
        // Skip excluded elements
        if (excludedTags.includes(node.nodeName)) {
            return;
        }

        // Skip hidden elements
        if (node.nodeType === Node.ELEMENT_NODE) {
            const style = window.getComputedStyle(node);
            if (style.display === 'none' || style.visibility === 'hidden') {
                return;
            }
        }

        // Add text nodes
        if (node.nodeType === Node.TEXT_NODE) {
            const text = node.textContent.trim();
            if (text) {
                textParts.push(text);
            }
        }

        // Traverse children
        if (node.childNodes) {
            for (const child of node.childNodes) {
                traverse(child);
            }
        }
    }

    traverse(element);
    return textParts.join(' ');
}

// Clean and normalize text
function cleanText(text) {
    return text
        .replace(/\s+/g, ' ')  // Normalize whitespace
        .replace(/\n+/g, '\n') // Normalize line breaks
        .trim();
}

// Listen for link clicks
document.addEventListener('click', (event) => {
    // Find the closest anchor element
    const link = event.target.closest('a');

    if (link && link.href) {
        // Send link click event to background script
        browser.runtime.sendMessage({
            action: 'linkClicked',
            event: {
                type: 'link_click',
                timestamp: Date.now(),
                url: link.href,
                title: link.textContent.trim() || link.title || link.href,
                details: {
                    currentUrl: window.location.href,
                    opensInNewTab: link.target === '_blank'
                }
            }
        });
    }
}, true); // Use capture phase to catch clicks before they navigate
