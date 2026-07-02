let currentTotal = 0
const items = new Map()
const selected = new Map()

function getResourceName() {
    const g = window.GetParentResourceName
    return typeof g === 'function' ? g() : 'leon_customs'
}

function post(name, data) {
    return fetch(`https://${getResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {})
    }).catch(() => {})
}

let isPointerOverUi = false

function bindPointerDetection() {
    document.addEventListener('mousemove', (e) => {
        const el = document.elementFromPoint(e.clientX, e.clientY)
        const over = !!(el && typeof el.closest === 'function' && el.closest('.panel'))
        
        if (over !== isPointerOverUi) {
            isPointerOverUi = over
            post('leon_pointer', { overUi: over })
        }
    }, true)
}

bindPointerDetection()

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return
    
    const ui = document.getElementById('ui-wrapper')
    if (!ui || !ui.classList.contains('leon-visible')) return
    
    e.preventDefault()
    ui.classList.remove('leon-visible')
    post('leon_close', {})
}, true)

function getGroupKey(item) {
    if (item.kind === 'extra') return `extra_${item.extraIndex}`
    if (item.kind === 'mod') return `mod_${item.modType}`
    if (item.kind === 'wheelType') return 'wheelType'
    if (item.kind === 'liveryNative') return 'livery'
    if (item.kind === 'turbo') return 'turbo'
    if (item.kind === 'xenon') return 'xenon'
    if (item.kind === 'primaryRgb') return 'primaryRgb'
    if (item.kind === 'secondaryRgb') return 'secondaryRgb'
    if (item.kind === 'pearl') return 'pearl'
    if (item.kind === 'wheelColor') return 'wheelColor'
    if (item.kind === 'interior') return 'interior'
    if (item.kind === 'dashboard') return 'dashboard'
    if (item.kind === 'neonToggle') return 'neonToggle'
    if (item.kind === 'neonRgb') return 'neonRgb'
    if (item.kind === 'windowTint') return 'windowTint'
    if (item.kind === 'plateIndex') return 'plateIndex'
    if (item.kind === 'xenonColor') return 'xenonColor'
    if (item.kind === 'tyreSmoke') return 'tyreSmoke'
    return item.id
}

function recalculateTotal() {
    let total = 0
    selected.forEach(entry => {
        if (entry && entry.item) {
            total += entry.item.price || 0
        }
    })
    currentTotal = total
    
    const el = document.getElementById('total-price')
    if (el) {
        el.textContent = `$${currentTotal.toLocaleString()}`
    }
    post('leon_cart', { total: currentTotal })
}

function selectItem(item, element) {
    const key = getGroupKey(item)
    const prev = selected.get(key)
    
    if (prev && prev.item && prev.item.id === item.id) {
        return
    }
    
    if (prev && prev.el) {
        prev.el.classList.remove('selected')
    }
    
    element.classList.add('selected')
    selected.set(key, { item, el: element })
    recalculateTotal()
    post('leon_preview', { item })
}

function bindItem(element, item) {
    items.set(item.id, item)
    element.addEventListener('click', () => selectItem(item, element))
}

function renderCategories(container, categories) {
    container.innerHTML = ''
    if (!categories || !categories.length) {
        container.innerHTML = '<p class="empty-hint">No options for this vehicle.</p>'
        return
    }
    
    categories.forEach(cat => {
        const acc = document.createElement('div')
        acc.className = 'accordion'
        
        const head = document.createElement('div')
        head.className = 'accordion-header'
        head.innerHTML = `${cat.title} <span class="arrow">▼</span>`
        const body = document.createElement('div')
        body.className = 'accordion-body'
        
        cat.items.forEach(item => {
            const row = document.createElement('div')
            row.className = 'part-item'
            row.dataset.id = item.id
            
            const left = document.createElement('span')
            left.textContent = item.label || item.id
            
            const right = document.createElement('span')
            right.className = 'part-price'
            right.textContent = item.price ? `$${Number(item.price).toLocaleString()}` : '$0'
            
            row.appendChild(left)
            row.appendChild(right)
            bindItem(row, item)
            body.appendChild(row)
        })
        
        head.addEventListener('click', () => {
            const open = body.classList.toggle('open')
            const arrow = head.querySelector('.arrow')
            if (arrow) {
                arrow.textContent = open ? '▲' : '▼'
            }
        })
        
        acc.appendChild(head)
        acc.appendChild(body)
        container.appendChild(acc)
    })
}

function createColorSection(parent, title, items, gridClass) {
    const section = document.createElement('div')
    section.className = 'color-section'
    
    const h = document.createElement('div')
    h.className = 'subsection-title'
    h.textContent = title
    
    const grid = document.createElement('div')
    grid.className = gridClass || 'color-grid'
    
    section.appendChild(h)
    section.appendChild(grid)
    parent.appendChild(section)
    return grid
}

function renderColorGrid(grid, items) {
    items.forEach(item => {
        const box = document.createElement('div')
        box.className = 'color-box'
        const [r, g, b] = item.rgb
        box.style.background = `rgb(${r},${g},${b})`
        bindItem(box, item)
        grid.appendChild(box)
    })
}

function renderIndexGrid(grid, items) {
    items.forEach(item => {
        const cell = document.createElement('div')
        cell.className = 'index-cell'
        cell.textContent = String(item.index)
        bindItem(cell, item)
        grid.appendChild(cell)
    })
}

function renderTintList(grid, items) {
    items.forEach(item => {
        const cell = document.createElement('div')
        cell.className = 'part-item'
        
        const left = document.createElement('span')
        left.textContent = item.label || `Tint ${item.index}`
        
        const right = document.createElement('span')
        right.className = 'part-price'
        right.textContent = `$${Number(item.price).toLocaleString()}`
        
        cell.appendChild(left)
        cell.appendChild(right)
        bindItem(cell, item)
        grid.appendChild(cell)
    })
}

function renderColorsTab(root, data) {
    root.innerHTML = ''
    
    const primaryGrid = createColorSection(root, 'BODY (PRIMARY RGB)', data.primary, 'color-grid')
    renderColorGrid(primaryGrid, data.primary)
    
    const secondaryGrid = createColorSection(root, 'BODY (SECONDARY RGB)', data.secondary, 'color-grid')
    renderColorGrid(secondaryGrid, data.secondary)
    
    const pearlGrid = createColorSection(root, 'PEARL / METALLIC (INDEX)', data.pearl, 'index-grid')
    renderIndexGrid(pearlGrid, data.pearl)
    
    const wheelGrid = createColorSection(root, 'RIMS (COLOR INDEX)', data.wheelColor, 'index-grid')
    renderIndexGrid(wheelGrid, data.wheelColor)
    
    const interiorGrid = createColorSection(root, 'INTERIOR (INDEX)', data.interior, 'index-grid')
    renderIndexGrid(interiorGrid, data.interior)
    
    const dashboardGrid = createColorSection(root, 'DASHBOARD (INDEX)', data.dashboard, 'index-grid')
    renderIndexGrid(dashboardGrid, data.dashboard)
    
    const neonSection = document.createElement('div')
    neonSection.className = 'color-section'
    neonSection.innerHTML = '<div class="subsection-title">NEON</div>'
    
    const neonRow = document.createElement('div')
    neonRow.className = 'accordion-body open'
    neonRow.style.display = 'block'
    
    data.neon.forEach(item => {
        const row = document.createElement('div')
        row.className = 'part-item'
        row.innerHTML = `<span>${item.label}</span><span class="part-price">${item.price ? '$' + Number(item.price).toLocaleString() : '$0'}</span>`
        bindItem(row, item)
        neonRow.appendChild(row)
    })
    neonSection.appendChild(neonRow)
    root.appendChild(neonSection)
    
    const neonColorsGrid = createColorSection(root, 'NEON RGB', data.neonColors, 'color-grid')
    renderColorGrid(neonColorsGrid, data.neonColors)
    
    const tintsList = createColorSection(root, 'WINDOW TINT', data.tints, 'tint-list')
    renderTintList(tintsList, data.tints)
    
    const platesList = createColorSection(root, 'PLATES (STYLE)', data.plates, 'tint-list')
    renderTintList(platesList, data.plates)
    
    const xenonList = createColorSection(root, 'XENON COLOR', data.xenonColors, 'tint-list')
    renderTintList(xenonList, data.xenonColors)
    
    const smokeGrid = createColorSection(root, 'TYRE SMOKE RGB', data.tyreSmoke, 'color-grid')
    renderColorGrid(smokeGrid, data.tyreSmoke)
}

function setVehicleInfo(vehicle) {
    document.getElementById('veh-class').textContent = vehicle.classLabel || '-'
    document.getElementById('veh-brand').textContent = vehicle.brand || '-'
    document.getElementById('veh-model').textContent = vehicle.modelName || '-'
    document.getElementById('veh-power-num').textContent = String(vehicle.powerScore ?? 0)
    
    const stats = vehicle.stats || {}
    const clamp = n => Math.max(0, Math.min(100, Number(n) || 0))
    
    document.getElementById('stat-power').textContent = String(stats.power ?? 0)
    document.getElementById('bar-power').style.width = `${clamp(stats.power)}%`
    
    document.getElementById('stat-speed').textContent = String(stats.topSpeed ?? 0)
    document.getElementById('bar-speed').style.width = `${clamp(stats.topSpeed)}%`
    
    document.getElementById('stat-accel').textContent = String(stats.acceleration ?? 0)
    document.getElementById('bar-accel').style.width = `${clamp(stats.acceleration)}%`
    
    document.getElementById('stat-brake').textContent = String(stats.brakes ?? 0)
    document.getElementById('bar-brake').style.width = `${clamp(stats.brakes)}%`
}

function resetUi() {
    items.clear()
    selected.clear()
    currentTotal = 0
    
    document.querySelectorAll('.selected').forEach(el => el.classList.remove('selected'))
    
    const total = document.getElementById('total-price')
    if (total) {
        total.textContent = '$0'
    }
}

document.querySelectorAll('.nav-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'))
        document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'))
        btn.classList.add('active')
        
        const target = btn.getAttribute('data-tab')
        const map = { visuals: 'tab-visuals', performance: 'tab-performance', colors: 'tab-colors' }
        const id = map[target]
        if (id) {
            document.getElementById(id).classList.add('active')
        }
    })
})

document.getElementById('btn-close').addEventListener('click', () => {
    document.getElementById('ui-wrapper').classList.remove('leon-visible')
    post('leon_close', {})
})

document.getElementById('btn-install').addEventListener('click', async () => {
    try {
        const r = await post('leon_install', { total: currentTotal })
        if (!r || !r.ok) {
            return
        }
        const j = await r.json()
        if (j && j.ok) {
            document.getElementById('ui-wrapper').classList.remove('leon-visible')
            resetUi()
        }
    } catch (e) {}
})

window.addEventListener('message', (event) => {
    const data = event.data
    if (!data || !data.type) return
    
    if (data.type === 'leon_open') {
        isPointerOverUi = false
        post('leon_pointer', { overUi: false })
        resetUi()
        setVehicleInfo(data.vehicle || {})
        renderCategories(document.getElementById('tab-visuals'), data.visual || [])
        renderCategories(document.getElementById('tab-performance'), data.performance || [])
        renderColorsTab(document.getElementById('tab-colors'), data.colors || {})
        document.getElementById('ui-wrapper').classList.add('leon-visible')
    }
    
    if (data.type === 'leon_hide') {
        isPointerOverUi = false
        post('leon_pointer', { overUi: false })
        document.getElementById('ui-wrapper').classList.remove('leon-visible')
        resetUi()
    }
})
