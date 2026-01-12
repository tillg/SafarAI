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

    // Tool: getPageStructure
    if (request.action === 'getPageStructure') {
        try {
            const structure = getPageStructure();
            sendResponse(JSON.stringify(structure));
        } catch (error) {
            sendResponse(JSON.stringify({ error: error.message }));
        }
        return true;
    }

    // Tool: getImage
    if (request.action === 'getImage') {
        try {
            const selector = request.params?.selector;
            const imageData = getImage(selector);
            sendResponse(JSON.stringify(imageData));
        } catch (error) {
            sendResponse(JSON.stringify({ error: error.message }));
        }
        return true;
    }

    // Tool: searchOnPage
    if (request.action === 'searchOnPage') {
        try {
            const query = request.params?.query;
            const results = searchOnPage(query);
            sendResponse(JSON.stringify(results));
        } catch (error) {
            sendResponse(JSON.stringify({ error: error.message }));
        }
        return true;
    }

    // Tool: getLinks
    if (request.action === 'getLinks') {
        try {
            const links = getLinks();
            sendResponse(JSON.stringify(links));
        } catch (error) {
            sendResponse(JSON.stringify({ error: error.message }));
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
        html: '',
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

    // Get rendered HTML (after JavaScript execution)
    content.html = document.documentElement.outerHTML;

    // Get main content text (fallback)
    content.text = extractMainText();

    // Truncate text to reasonable length (10,000 chars ~ 2,500 tokens)
    if (content.text.length > 10000) {
        content.text = content.text.substring(0, 10000) + '...';
    }

    console.log('Extracted page content:', {
        url: content.url,
        title: content.title,
        htmlLength: content.html.length,
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

// MARK: - Tool Implementations

function getPageStructure() {
    const structure = {
        url: window.location.href,
        title: document.title,
        headings: [],
        sections: [],
        mainContent: null
    };

    // Extract headings
    document.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach((heading, index) => {
        structure.headings.push({
            level: parseInt(heading.tagName[1]),
            text: heading.textContent.trim(),
            index: index
        });
    });

    // Extract main sections
    document.querySelectorAll('main, article, section').forEach((section, index) => {
        const headingInSection = section.querySelector('h1, h2, h3, h4, h5, h6');
        structure.sections.push({
            type: section.tagName.toLowerCase(),
            heading: headingInSection ? headingInSection.textContent.trim() : null,
            textLength: section.textContent.trim().length,
            index: index
        });
    });

    // Identify main content
    const main = document.querySelector('main, article, [role="main"]');
    if (main) {
        structure.mainContent = {
            tag: main.tagName.toLowerCase(),
            textLength: main.textContent.trim().length
        };
    }

    return structure;
}

function getImage(selector) {
    if (!selector) {
        throw new Error('Selector required');
    }

    const img = document.querySelector(selector);

    if (!img || img.tagName !== 'IMG') {
        throw new Error('No image found with selector: ' + selector);
    }

    return {
        url: img.src,
        alt: img.alt || '',
        width: img.naturalWidth || img.width,
        height: img.naturalHeight || img.height,
        selector: selector
    };
}

function searchOnPage(query) {
    if (!query) {
        throw new Error('Query required');
    }

    const results = [];
    const bodyText = document.body.innerText;
    const lowerQuery = query.toLowerCase();
    const lowerText = bodyText.toLowerCase();

    let index = 0;
    let position = lowerText.indexOf(lowerQuery, index);

    while (position !== -1 && results.length < 10) {
        // Get context around match (50 chars before and after)
        const start = Math.max(0, position - 50);
        const end = Math.min(bodyText.length, position + query.length + 50);
        const context = bodyText.substring(start, end);

        results.push({
            match: bodyText.substring(position, position + query.length),
            context: '...' + context + '...',
            position: position
        });

        index = position + query.length;
        position = lowerText.indexOf(lowerQuery, index);
    }

    return {
        query: query,
        totalMatches: results.length,
        results: results
    };
}

function getLinks() {
    const links = [];
    const seen = new Set();

    document.querySelectorAll('a[href]').forEach((link) => {
        const href = link.href;

        // Skip duplicates and non-http links
        if (seen.has(href) || (!href.startsWith('http://') && !href.startsWith('https://'))) {
            return;
        }

        seen.add(href);

        if (links.length < 100) { // Limit to 100 links
            links.push({
                url: href,
                text: link.textContent.trim() || link.title || href,
                title: link.title || ''
            });
        }
    });

    return {
        totalLinks: links.length,
        links: links
    };
}
