// odpkg docs - JavaScript

// Tab switching
function showTab(tabId) {
    // Hide all tab contents
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
    });
    
    // Deactivate all tabs
    document.querySelectorAll('.tab').forEach(tab => {
        tab.classList.remove('active');
    });
    
    // Show selected tab content
    document.getElementById(tabId).classList.add('active');
    
    // Activate clicked tab
    event.target.classList.add('active');
}

// Copy code to clipboard
function copyCode(button) {
    const codeBlock = button.closest('.code-block');
    const code = codeBlock.querySelector('code').innerText;
    
    navigator.clipboard.writeText(code).then(() => {
        const originalText = button.innerText;
        button.innerText = 'Copied!';
        setTimeout(() => {
            button.innerText = originalText;
        }, 2000);
    });
}

// Search modal
function toggleSearch() {
    const modal = document.getElementById('search-modal');
    modal.classList.toggle('hidden');
    
    if (!modal.classList.contains('hidden')) {
        document.getElementById('search-input').focus();
    }
}

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
    // Cmd/Ctrl + K to open search
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        toggleSearch();
    }
    
    // Escape to close search
    if (e.key === 'Escape') {
        document.getElementById('search-modal').classList.add('hidden');
    }
});

// Close modal when clicking outside
document.getElementById('search-modal')?.addEventListener('click', (e) => {
    if (e.target.id === 'search-modal') {
        toggleSearch();
    }
});

// Highlight active section in sidebar
function updateActiveSection() {
    const sections = document.querySelectorAll('.section');
    const navItems = document.querySelectorAll('.nav-item');
    const tocItems = document.querySelectorAll('.toc-item');
    
    let currentSection = '';
    
    sections.forEach(section => {
        const rect = section.getBoundingClientRect();
        if (rect.top <= 100) {
            currentSection = section.id;
        }
    });
    
    navItems.forEach(item => {
        item.classList.remove('active');
        if (item.getAttribute('href') === '#' + currentSection) {
            item.classList.add('active');
        }
    });
    
    tocItems.forEach(item => {
        item.classList.remove('active');
        if (item.getAttribute('href') === '#' + currentSection) {
            item.classList.add('active');
        }
    });
}

// Throttled scroll handler
let ticking = false;
document.addEventListener('scroll', () => {
    if (!ticking) {
        requestAnimationFrame(() => {
            updateActiveSection();
            ticking = false;
        });
        ticking = true;
    }
});

// Initial highlight
updateActiveSection();

// Simple search functionality
document.getElementById('search-input')?.addEventListener('input', (e) => {
    const query = e.target.value.toLowerCase();
    const results = document.getElementById('search-results');
    
    if (query.length < 2) {
        results.innerHTML = '';
        return;
    }
    
    const sections = document.querySelectorAll('.section');
    const matches = [];
    
    sections.forEach(section => {
        const heading = section.querySelector('h1, h2');
        const text = section.innerText.toLowerCase();
        
        if (text.includes(query) && heading) {
            matches.push({
                id: section.id,
                title: heading.innerText,
                snippet: text.substring(0, 100) + '...'
            });
        }
    });
    
    if (matches.length === 0) {
        results.innerHTML = '<p style="padding: 16px; color: #666;">No results found</p>';
        return;
    }
    
    results.innerHTML = matches.map(m => `
        <a href="#${m.id}" style="display: block; padding: 12px 16px; text-decoration: none; color: inherit; border-bottom: 1px solid #eee;" onclick="toggleSearch()">
            <strong>${m.title}</strong>
        </a>
    `).join('');
});
