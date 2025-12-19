// MacTree - Vanilla JavaScript app
// No frameworks, minimal dependencies per constitution

console.log('MacTree UI initializing...');

// Application state
const state = {
    currentPath: null,
    scanInProgress: false,
    entries: new Map(), // path -> FileEntry
    aggregates: new Map(), // path -> DirAggregate
    focusPath: null,
    searchText: '',
    minSizeMB: null,
    sortColumn: 'size',
    sortDirection: 'desc',
    stats: {
        itemsScanned: 0,
        totalSize: 0,
        errors: 0
    },
    treemapLayout: [], // Store layout for click detection
    selectedPath: null // Currently selected file/folder
};

// Pending render updates (for RAF batching)
let pendingRenderUpdate = false;
let pendingTreeData = {
    entries: [],
    aggregates: []
};

// Initialize UI
document.addEventListener('DOMContentLoaded', () => {
    console.log('DOM loaded, setting up event handlers...');
    setupEventHandlers();
    updateUI();
});

function setupEventHandlers() {
    // Folder selection
    document.getElementById('select-folder-btn').addEventListener('click', selectFolder);
    
    // Scan controls
    document.getElementById('scan-btn').addEventListener('click', startScan);
    document.getElementById('cancel-btn').addEventListener('click', cancelScan);
    document.getElementById('rescan-btn').addEventListener('click', rescan);
    
    // Search/filter
    document.getElementById('search-input').addEventListener('input', handleSearchInput);
    document.getElementById('min-size-input').addEventListener('input', handleMinSizeInput);
    
    // Error panel
    document.getElementById('close-errors-btn').addEventListener('click', closeErrorPanel);
    
    // Action buttons
    document.getElementById('show-finder-btn').addEventListener('click', showSelectedInFinder);
    document.getElementById('open-folder-btn').addEventListener('click', openSelectedFolder);
    
    // Column headers for sorting (to be implemented)
    document.querySelectorAll('#tree-table-header > div').forEach(header => {
        header.style.cursor = 'pointer';
        header.addEventListener('click', handleColumnClick);
    });
    
    // Treemap interactions
    const canvas = document.getElementById('treemap-canvas');
    console.log('Setting up treemap canvas event listeners');
    
    if (!canvas) {
        console.error('ERROR: treemap-canvas not found!');
        return;
    }
    
    // Test that ANY click works
    canvas.addEventListener('click', (e) => {
        console.log('CLICK EVENT FIRED! button:', e.button, 'alt:', e.altKey, 'ctrl:', e.ctrlKey);
    });
    
    // Use mousedown for right-click detection (WKWebView blocks contextmenu)
    canvas.addEventListener('mousedown', handleTreemapMouseDown);
    canvas.addEventListener('click', handleTreemapClick);
    
    console.log('Treemap event listeners attached to canvas');
}

function selectFolder() {
    console.log('Select folder clicked');
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.selectFolder) {
        window.webkit.messageHandlers.selectFolder.postMessage({});
    } else {
        console.error('Native bridge not available');
    }
}

function startScan() {
    console.log('Start scan clicked');
    if (!state.currentPath) {
        console.error('No path selected');
        return;
    }
    
    // Clear previous scan data
    state.entries.clear();
    state.aggregates.clear();
    state.stats = { itemsScanned: 0, totalSize: 0, errors: 0 };
    
    state.scanInProgress = true;
    updateUI();
    clearTreeTable();
    clearTreemap();
    
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.startScan) {
        window.webkit.messageHandlers.startScan.postMessage({ path: state.currentPath });
    } else {
        console.error('Native bridge not available');
    }
}

function cancelScan() {
    console.log('Cancel scan clicked');
    
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cancelScan) {
        window.webkit.messageHandlers.cancelScan.postMessage({});
    } else {
        console.error('Native bridge not available');
    }
}

function rescan() {
    console.log('Rescan clicked');
    // TODO: T058 - Implement rescan
}

function handleSearchInput(event) {
    state.searchText = event.target.value.toLowerCase();
    console.log('Search:', state.searchText);
    filterAndRender();
}

function handleMinSizeInput(event) {
    const value = parseFloat(event.target.value);
    state.minSizeMB = isNaN(value) ? null : value;
    console.log('Min size MB:', state.minSizeMB);
    filterAndRender();
}

function handleTreemapMouseDown(event) {
    console.log('handleTreemapMouseDown called! button:', event.button, 'altKey:', event.altKey, 'ctrlKey:', event.ctrlKey);
    
    // Check if it's a right-click (button === 2) or Option+click (altKey)
    const isContextClick = event.button === 2 || event.altKey || (event.button === 0 && event.ctrlKey);
    
    console.log('isContextClick:', isContextClick);
    
    if (!isContextClick) {
        console.log('Not a context click, returning');
        return;
    }
    
    alert('Context click detected!');
    
    event.preventDefault();
    event.stopPropagation();
    console.log('Context click detected on treemap');
    
    const canvas = event.target;
    const rect = canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    
    console.log('Click coords:', x, y, 'Layout items:', state.treemapLayout.length);
    
    // Find which rectangle was clicked
    const clickedRect = state.treemapLayout.find(r => 
        x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h
    );
    
    if (!clickedRect) {
        console.log('No rectangle found at click position');
        return;
    }
    
    console.log('Clicked rectangle:', clickedRect.name);
    
    // Show options menu
    const menuItems = [];
    
    if (clickedRect.isDir) {
        menuItems.push('Enter Folder');
    }
    menuItems.push('Show in Finder');
    
    // Use prompt to select action
    const action = prompt(`Right-clicked: ${clickedRect.name}\n\nOptions:\n${menuItems.map((item, i) => `${i + 1}. ${item}`).join('\n')}\n\nEnter number:`);
    
    if (action === '1' && clickedRect.isDir) {
        // Enter folder
        state.focusPath = clickedRect.path;
        renderTreeTable();
        renderTreemap();
    } else if ((action === '2' && clickedRect.isDir) || (action === '1' && !clickedRect.isDir)) {
        // Show in Finder
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.revealInFinder) {
            window.webkit.messageHandlers.revealInFinder.postMessage({ path: clickedRect.path });
        }
    }
}

function handleTreemapClick(event) {
    const canvas = event.target;
    const rect = canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    
    // Find which rectangle was clicked
    const clickedRect = state.treemapLayout.find(r => 
        x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h
    );
    
    if (!clickedRect) return;
    
    // Double-click to enter folder
    if (event.detail === 2 && clickedRect.isDir) {
        state.focusPath = clickedRect.path;
        renderTreeTable();
        renderTreemap();
        return;
    }
    
    // Single click - select the corresponding row in the tree table
    selectRowByPath(clickedRect.path);
}

function selectRowByPath(path) {
    // Find and select the row in the tree table
    const rows = document.querySelectorAll('.tree-row');
    let selectedRow = null;
    rows.forEach(row => {
        if (row.dataset.path === path) {
            row.classList.add('selected');
            row.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
            selectedRow = row;
        } else {
            row.classList.remove('selected');
        }
    });
    
    // Show/hide action buttons based on selection
    const showFinderBtn = document.getElementById('show-finder-btn');
    const openFolderBtn = document.getElementById('open-folder-btn');
    
    if (selectedRow) {
        const isDir = selectedRow.dataset.isdir === 'true';
        showFinderBtn.classList.remove('hidden');
        if (isDir) {
            openFolderBtn.classList.remove('hidden');
        } else {
            openFolderBtn.classList.add('hidden');
        }
        
        // Store selected path in state
        state.selectedPath = path;
    } else {
        showFinderBtn.classList.add('hidden');
        openFolderBtn.classList.add('hidden');
        state.selectedPath = null;
    }
}

function showContextMenu(clickedRect) {
    const menuItems = [];
    
    if (clickedRect.isDir) {
        menuItems.push('Enter Folder');
    }
    menuItems.push('Show in Finder');
    
    const action = prompt(`⌘+Clicked: ${clickedRect.name}\n\nOptions:\n${menuItems.map((item, i) => `${i + 1}. ${item}`).join('\n')}\n\nEnter number:`);
    
    if (action === '1' && clickedRect.isDir) {
        // Enter folder
        state.focusPath = clickedRect.path;
        renderTreeTable();
        renderTreemap();
    } else if ((action === '2' && clickedRect.isDir) || (action === '1' && !clickedRect.isDir)) {
        // Show in Finder
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.revealInFinder) {
            window.webkit.messageHandlers.revealInFinder.postMessage({ path: clickedRect.path });
        }
    }
}

function handleColumnClick(event) {
    const column = event.target.className.replace('col-', '');
    console.log('Column clicked:', column);
    // TODO: T052-T054 - Implement sorting
}

function filterAndRender() {
    // TODO: T047-T051 - Implement filtering
    console.log('Filter and render (placeholder)');
}

function closeErrorPanel() {
    document.getElementById('error-panel').classList.add('hidden');
}

function showSelectedInFinder() {
    if (!state.selectedPath) return;
    
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.revealInFinder) {
        window.webkit.messageHandlers.revealInFinder.postMessage({ path: state.selectedPath });
    }
}

function openSelectedFolder() {
    if (!state.selectedPath) return;
    
    const rows = document.querySelectorAll('.tree-row');
    rows.forEach(row => {
        if (row.dataset.path === state.selectedPath) {
            const isDir = row.dataset.isdir === 'true';
            if (isDir) {
                focusPath(state.selectedPath);
            }
        }
    });
}

function updateUI() {
    // Update button states
    const scanBtn = document.getElementById('scan-btn');
    const cancelBtn = document.getElementById('cancel-btn');
    const rescanBtn = document.getElementById('rescan-btn');
    
    scanBtn.disabled = state.scanInProgress || !state.currentPath;
    cancelBtn.disabled = !state.scanInProgress;
    rescanBtn.disabled = state.scanInProgress || !state.currentPath;
    
    // Update progress
    const progressText = document.getElementById('progress-text');
    if (state.scanInProgress) {
        const sizeText = formatSize(state.stats.totalSize);
        progressText.textContent = `Scanning... ${state.stats.itemsScanned.toLocaleString()} items, ${sizeText}`;
    } else if (state.currentPath) {
        progressText.textContent = `Ready - ${state.entries.size.toLocaleString()} items`;
    } else {
        progressText.textContent = 'No folder selected';
    }
    
    // Update selected path display
    const pathDisplay = document.querySelector('.path-display');
    if (pathDisplay) {
        pathDisplay.textContent = state.currentPath || 'No folder selected';
    }
}

// MARK: - Native Event Receiver

window.receiveNativeEvent = function(eventName, jsonString) {
    try {
        console.log('RAW EVENT:', eventName, 'JSON:', jsonString);
        const data = JSON.parse(jsonString);
        console.log('PARSED:', eventName, data);
        
        switch (eventName) {
            case 'folderSelected':
                handleFolderSelected(data);
                break;
            case 'scanStarted':
                handleScanStarted(data);
                break;
            case 'scanProgress':
                handleScanProgress(data);
                break;
            case 'treeDataDelta':
                handleTreeDataDelta(data);
                break;
            case 'scanCompleted':
                handleScanCompleted(data);
                break;
            case 'scanCancelled':
                handleScanCancelled(data);
                break;
            case 'scanError':
                handleScanError(data);
                break;
            default:
                console.warn('Unknown event:', eventName);
        }
    } catch (error) {
        console.error('Failed to process native event:', error);
    }
};

function handleFolderSelected(data) {
    if (data.cancelled) {
        console.log('Folder selection cancelled');
        return;
    }
    
    state.currentPath = data.path;
    console.log('Folder selected:', data.path);
    updateUI();
}

function handleScanStarted(data) {
    console.log('Scan started:', data.sessionId);
    state.scanInProgress = true;
    updateUI();
}

function handleScanProgress(data) {
    state.stats.itemsScanned = data.itemsScanned;
    state.stats.totalSize = data.totalSize;
    state.stats.errors = data.errors || 0;
    updateUI();
}

function handleTreeDataDelta(data) {
    // Store incoming data for batched rendering
    pendingTreeData.entries.push(...data.entries);
    pendingTreeData.aggregates.push(...data.aggregates);
    
    // Schedule render update via RAF (T039)
    if (!pendingRenderUpdate) {
        pendingRenderUpdate = true;
        requestAnimationFrame(processTreeDataBatch);
    }
}

function processTreeDataBatch() {
    // Add entries to state
    for (const entry of pendingTreeData.entries) {
        state.entries.set(entry.path, entry);
    }
    
    // Add aggregates to state
    for (const agg of pendingTreeData.aggregates) {
        state.aggregates.set(agg.path, agg);
    }
    
    // Render updates
    renderTreeTable();
    renderTreemap();
    
    // Clear pending data
    pendingTreeData.entries = [];
    pendingTreeData.aggregates = [];
    pendingRenderUpdate = false;
}

function handleScanCompleted(data) {
    console.log('Scan completed:', data);
    state.scanInProgress = false;
    state.stats.itemsScanned = data.totalItems;
    state.stats.totalSize = data.totalSize;
    updateUI();
}

function handleScanCancelled(data) {
    console.log('Scan cancelled:', data);
    state.scanInProgress = false;
    updateUI();
}

function handleScanError(data) {
    console.error('Scan error:', data.error);
    state.scanInProgress = false;
    showError(data.error);
    updateUI();
}

function showError(message) {
    const errorPanel = document.getElementById('error-panel');
    const errorList = document.getElementById('error-list');
    
    const errorItem = document.createElement('div');
    errorItem.textContent = message;
    errorList.appendChild(errorItem);
    
    errorPanel.classList.remove('hidden');
}

// MARK: - Rendering Functions

function clearTreeTable() {
    const tableBody = document.getElementById('tree-table-body');
    tableBody.innerHTML = '<div class="placeholder">Scanning...</div>';
}

function clearTreemap() {
    const canvas = document.getElementById('treemap-canvas');
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = '#666';
    ctx.font = '14px -apple-system';
    ctx.textAlign = 'center';
    ctx.fillText('Scanning...', canvas.width / 2, canvas.height / 2);
}

function renderTreeTable() {
    const tableBody = document.getElementById('tree-table-body');
    
    if (state.entries.size === 0) {
        tableBody.innerHTML = '<div class="placeholder">No data yet</div>';
        return;
    }
    
    // Get focused path entries or root entries
    const focusPath = state.focusPath || state.currentPath;
    const displayEntries = Array.from(state.entries.values())
        .filter(entry => {
            const parent = entry.parentPath || entry.parent;
            // Show direct children of focus path
            return parent === focusPath;
        });
    
    // Sort entries
    displayEntries.sort((a, b) => {
        if (state.sortColumn === 'name') {
            return state.sortDirection === 'asc' 
                ? a.name.localeCompare(b.name)
                : b.name.localeCompare(a.name);
        } else if (state.sortColumn === 'size') {
            return state.sortDirection === 'asc'
                ? a.size - b.size
                : b.size - a.size;
        }
        return 0;
    });
    
    // Build rows (basic, non-virtualized)
    const rows = displayEntries.slice(0, 1000).map(entry => {
        const agg = state.aggregates.get(entry.path);
        const displaySize = entry.type === 'directory' && agg ? agg.totalSize : entry.size;
        const icon = entry.type === 'directory' ? '📁' : '📄';
        const isDir = entry.type === 'directory';
        
        return `
            <div class="tree-row" data-path="${escapeHtml(entry.path)}" data-name="${escapeHtml(entry.name)}" data-isdir="${isDir}">
                <div class="col-name">${icon} ${escapeHtml(entry.name)}</div>
                <div class="col-size">${formatSize(displaySize)}</div>
                <div class="col-items">${agg ? agg.fileCount + agg.dirCount : '-'}</div>
                <div class="col-path">${escapeHtml(entry.path)}</div>
            </div>
        `;
    }).join('');
    
    tableBody.innerHTML = rows;
    
    // Add click handlers
    tableBody.querySelectorAll('.tree-row').forEach(row => {
        row.addEventListener('click', () => {
            const path = row.dataset.path;
            
            // Select this row
            document.querySelectorAll('.tree-row').forEach(r => r.classList.remove('selected'));
            row.classList.add('selected');
        });
        
        row.addEventListener('dblclick', () => {
            const path = row.dataset.path;
            const isDir = row.dataset.isdir === 'true';
            
            // Double-click to enter folder
            if (isDir) {
                focusPath(path);
            }
        });
        
        // Right-click context menu using mousedown (WKWebView blocks contextmenu)
        row.addEventListener('mousedown', (e) => {
            // Check for right-click (button 2) or Control+click
            if (e.button !== 2 && !e.ctrlKey) {
                return;
            }
            
            e.preventDefault();
            const path = row.dataset.path;
            const name = row.dataset.name;
            const isDir = row.dataset.isdir === 'true';
            
            // Select this row
            document.querySelectorAll('.tree-row').forEach(r => r.classList.remove('selected'));
            row.classList.add('selected');
            
            // Show context menu
            const menuItems = [];
            if (isDir) {
                menuItems.push('Open Folder');
            }
            menuItems.push('Show in Finder');
            
            const action = prompt(`${name}\n\nOptions:\n${menuItems.map((item, i) => `${i + 1}. ${item}`).join('\n')}\n\nEnter number:`);
            
            if (action === '1' && isDir) {
                focusPath(path);
            } else if ((action === '2' && isDir) || (action === '1' && !isDir)) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.revealInFinder) {
                    window.webkit.messageHandlers.revealInFinder.postMessage({ path: path });
                }
            }
        });
    });
}

function renderTreemap() {
    const canvas = document.getElementById('treemap-canvas');
    const ctx = canvas.getContext('2d');
    
    // Set canvas size to match container
    const rect = canvas.getBoundingClientRect();
    canvas.width = rect.width;
    canvas.height = rect.height;
    
    // Dark mode background
    ctx.fillStyle = '#1e1e1e';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    if (state.entries.size === 0) {
        ctx.fillStyle = '#999';
        ctx.font = '14px -apple-system';
        ctx.textAlign = 'center';
        ctx.fillText('No data yet', canvas.width / 2, canvas.height / 2);
        return;
    }
    
    // Get top-level entries for current focus
    const focusPath = state.focusPath || state.currentPath;
    const entries = Array.from(state.entries.values())
        .filter(entry => {
            const parent = entry.parentPath || entry.parent;
            // Show direct children of focus path
            return parent === focusPath;
        });
    
    // Build treemap data
    const items = entries.map(entry => {
        const agg = state.aggregates.get(entry.path);
        const size = entry.type === 'directory' && agg ? agg.totalSize : entry.size;
        return {
            name: entry.name,
            path: entry.path,
            size: size,
            actualSize: size, // Keep actual size for display
            isDir: entry.type === 'directory'
        };
    }).filter(item => item.size > 0);
    
    if (items.length === 0) return;
    
    // Apply square root scaling to compress size differences
    // This makes big files still the biggest, but not overwhelmingly so
    const scaledItems = items.map(item => ({
        ...item,
        size: Math.sqrt(item.size)
    })).sort((a, b) => b.size - a.size);
    
    // Squarified treemap algorithm
    const bounds = { x: 0, y: 0, w: canvas.width, h: canvas.height };
    const layout = squarify(scaledItems, bounds);
    
    // Store layout for click detection
    state.treemapLayout = layout;
    
    // Render rectangles
    for (const rect of layout) {
        // Generate color
        const color = getColorForPath(rect.path);
        ctx.fillStyle = color;
        ctx.fillRect(rect.x, rect.y, rect.w, rect.h);
        
        // Border
        ctx.strokeStyle = '#000';
        ctx.lineWidth = 1;
        ctx.strokeRect(rect.x + 0.5, rect.y + 0.5, rect.w - 1, rect.h - 1);
        
        // Label
        if (rect.w > 30 && rect.h > 20) {
            ctx.fillStyle = '#fff';
            ctx.font = '11px -apple-system';
            ctx.textAlign = 'left';
            ctx.textBaseline = 'top';
            
            const padding = 4;
            const maxWidth = rect.w - padding * 2;
            
            // Truncate name if needed
            let displayName = rect.name;
            ctx.fillText(displayName, rect.x + padding, rect.y + padding, maxWidth);
            
            // Size (use actualSize for display, not scaled size)
            if (rect.h > 35) {
                ctx.font = '10px -apple-system';
                ctx.fillStyle = 'rgba(255, 255, 255, 0.8)';
                ctx.fillText(formatSize(rect.actualSize || rect.size), rect.x + padding, rect.y + padding + 14, maxWidth);
            }
        }
    }
}

// Squarified treemap algorithm
function squarify(items, bounds) {
    const totalSize = items.reduce((sum, item) => sum + item.size, 0);
    if (totalSize === 0) return [];
    
    const result = [];
    const normalized = items.map(item => ({
        ...item,
        normalizedSize: item.size / totalSize * bounds.w * bounds.h
    }));
    
    const rows = [];
    let remaining = [...normalized];
    let currentRow = [];
    let x = bounds.x;
    let y = bounds.y;
    let w = bounds.w;
    let h = bounds.h;
    
    while (remaining.length > 0) {
        const item = remaining.shift();
        
        // Check if adding this item improves aspect ratio
        if (currentRow.length === 0) {
            currentRow.push(item);
        } else {
            const currentWorst = worstAspect(currentRow, w, h);
            const withNewWorst = worstAspect([...currentRow, item], w, h);
            
            if (withNewWorst < currentWorst) {
                // Adding improves aspect ratio - add to current row
                currentRow.push(item);
            } else {
                // Adding worsens aspect ratio - lay out current row and start new one
                const rowSum = currentRow.reduce((sum, i) => sum + i.normalizedSize, 0);
                const isHorizontal = w >= h;
                
                if (isHorizontal) {
                    const rowHeight = rowSum / w;
                    let itemX = x;
                    for (const rowItem of currentRow) {
                        const itemWidth = rowItem.normalizedSize / rowHeight;
                        result.push({
                            ...rowItem,
                            x: itemX,
                            y: y,
                            w: itemWidth,
                            h: rowHeight
                        });
                        itemX += itemWidth;
                    }
                    y += rowHeight;
                    h -= rowHeight;
                } else {
                    const rowWidth = rowSum / h;
                    let itemY = y;
                    for (const rowItem of currentRow) {
                        const itemHeight = rowItem.normalizedSize / rowWidth;
                        result.push({
                            ...rowItem,
                            x: x,
                            y: itemY,
                            w: rowWidth,
                            h: itemHeight
                        });
                        itemY += itemHeight;
                    }
                    x += rowWidth;
                    w -= rowWidth;
                }
                
                // Start new row with the item that didn't fit
                currentRow = [item];
            }
        }
    }
    
    // Lay out remaining row
    if (currentRow.length > 0) {
        const rowSum = currentRow.reduce((sum, i) => sum + i.normalizedSize, 0);
        const isHorizontal = w >= h;
        
        if (isHorizontal) {
            const rowHeight = rowSum / w;
            let itemX = x;
            for (const rowItem of currentRow) {
                const itemWidth = rowItem.normalizedSize / rowHeight;
                result.push({
                    ...rowItem,
                    x: itemX,
                    y: y,
                    w: itemWidth,
                    h: rowHeight
                });
                itemX += itemWidth;
            }
        } else {
            const rowWidth = rowSum / h;
            let itemY = y;
            for (const rowItem of currentRow) {
                const itemHeight = rowItem.normalizedSize / rowWidth;
                result.push({
                    ...rowItem,
                    x: x,
                    y: itemY,
                    w: rowWidth,
                    h: itemHeight
                });
                itemY += itemHeight;
            }
        }
    }
    
    return result;
}

function worstAspect(row, w, h) {
    if (row.length === 0) return Infinity;
    
    const rowSum = row.reduce((sum, item) => sum + item.normalizedSize, 0);
    if (rowSum === 0) return Infinity;
    
    const isHorizontal = w >= h;
    let worst = 0;
    
    if (isHorizontal) {
        // Row goes horizontally
        const rowHeight = rowSum / w;
        for (const item of row) {
            const itemWidth = item.normalizedSize / rowHeight;
            const aspect = Math.max(itemWidth / rowHeight, rowHeight / itemWidth);
            worst = Math.max(worst, aspect);
        }
    } else {
        // Row goes vertically
        const rowWidth = rowSum / h;
        for (const item of row) {
            const itemHeight = item.normalizedSize / rowWidth;
            const aspect = Math.max(itemHeight / rowWidth, rowWidth / itemHeight);
            worst = Math.max(worst, aspect);
        }
    }
    
    return worst;
}

// Generate consistent colors per path
const colorCache = new Map();
function getColorForPath(path) {
    if (colorCache.has(path)) return colorCache.get(path);
    
    // Hash path to number
    let hash = 0;
    for (let i = 0; i < path.length; i++) {
        hash = ((hash << 5) - hash) + path.charCodeAt(i);
        hash = hash & hash;
    }
    
    // Generate HSL color
    const hue = Math.abs(hash % 360);
    const sat = 60 + (Math.abs(hash >> 8) % 20);
    const light = 45 + (Math.abs(hash >> 16) % 15);
    const color = `hsl(${hue}, ${sat}%, ${light}%)`;
    
    colorCache.set(path, color);
    return color;
}

// MARK: - Utility Functions

function formatSize(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function focusPath(path) {
    console.log('Focus path:', path);
    state.focusPath = path;
    renderTreeTable();
    renderTreemap();
}

// Export for potential native bridge calls
window.MacTreeApp = {
    state,
    updateUI,
    renderTreeTable,
    renderTreemap
};

console.log('MacTree UI ready');
