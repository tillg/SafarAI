console.log('SafarAI content script loaded on:', window.location.href);

// Listen for requests from popup
browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log('Content script received message:', request);

    if (request.action === 'getPageContent') {
        const content = extractPageContent();
        sendResponse(content);
        return true;
    }

    return false;
});

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
