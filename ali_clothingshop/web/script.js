let originalSkinJS = {};
let itemPrice = 0;
let currentPrice = 0; // This will store the calculated total price
let isRightMouseDown = false;

function toggleItem(header) {
    const currentItem = header.closest('.is-category');
    if (!currentItem) return;
    const isAlreadyExpanded = currentItem.classList.contains('expanded');
    document.querySelectorAll('.is-category').forEach(item => item.classList.remove('expanded'));
    if (!isAlreadyExpanded) {
        currentItem.classList.add('expanded');
    }
}

function toggleSubItem(header) {
    const item = header.parentElement;
    item.classList.toggle('expanded');
}

function resetPurchaseButtons() {
    document.querySelectorAll('.purchase-btn[data-confirm="true"]').forEach(btn => {
        const originalText = btn.id === 'purchase-bank' ? 'BANK' : 'BAR';
        // Reset to just the button text without price
        btn.innerHTML = originalText;
        btn.removeAttribute('data-confirm');
    });
}

// Function to calculate the total price based on changed items
function calculateTotalPrice() {
    let changedItemsCount = 0;
    document.querySelectorAll('.clothing-item').forEach(item => {
        const categoryName = item.querySelector('.item-name').textContent;
        const slider = item.querySelector('.slider');

        // Check if the slider exists and we have original skin data for this category
        if (slider && originalSkinJS && (originalSkinJS[categoryName] !== undefined || originalSkinJS[categoryName.replace(' FARBE', '')] !== undefined)) {
            let originalValue = undefined;

            // Determine the correct original value to compare against (drawable or texture)
            if (categoryName.includes('FARBE')) {
                const baseCategory = categoryName.replace(' FARBE', '');
                if (originalSkinJS[baseCategory] && originalSkinJS[baseCategory].texture !== undefined) {
                    originalValue = originalSkinJS[baseCategory].texture;
                }
            } else {
                 if (originalSkinJS[categoryName] && originalSkinJS[categoryName].drawable !== undefined) {
                    originalValue = originalSkinJS[categoryName].drawable;
                }
            }

            // If we have an original value and the current slider value is different, and it's not an arm item, increment count
            if (originalValue !== undefined && 
                parseInt(slider.value, 10) !== originalValue) {
                // Only exclude ARME (Arms) from counting towards the price
                if (!categoryName.includes('ARME')) {
                    changedItemsCount++;
                }
            }
        }
    });
    return changedItemsCount * itemPrice;
}

// Function to update the price displayed on the purchase buttons
function updatePriceDisplay() {
    currentPrice = calculateTotalPrice();
    document.querySelectorAll('.purchase-btn').forEach(btn => {
        const priceTag = btn.querySelector('.price-tag');
        if (priceTag) {
            priceTag.textContent = '$' + currentPrice;
        }
        // If the button is in confirmation state, update its text to reflect the current price
        if (btn.getAttribute('data-confirm') === 'true') {
            btn.textContent = `${currentPrice}$ | BESTÄTIGEN`;
        }
    });
}

function purchaseOutfit(method, btn) {
    // Prevent purchasing if the total price is 0
    if (currentPrice === 0) {
        resetPurchaseButtons(); // Reset buttons if no changes were made
        return;
    }

    // Reset any other purchase buttons that might be in a confirmation state
    document.querySelectorAll('.purchase-btn').forEach(button => {
        if (button !== btn && button.getAttribute('data-confirm') === 'true') {
            const originalText = button.id === 'purchase-bank' ? 'BANK' : 'BAR';
             // Use innerHTML to preserve the span tag for the price
             updatePriceDisplay();
             button.innerHTML = originalText + ' <span class="price-tag">$' + calculateTotalPrice() + '</span>';
            button.removeAttribute('data-confirm');
        }
    });

    // If the clicked button is already in a confirmation state, proceed with purchase
    if (btn.getAttribute('data-confirm') === 'true') {
        const changedOutfitData = {};
        // Collect only the changed items to send to the server
         document.querySelectorAll('.clothing-item').forEach(item => {
            const categoryName = item.querySelector('.item-name').textContent;
            const slider = item.querySelector('.slider');
             if (slider && originalSkinJS && (originalSkinJS[categoryName] !== undefined || originalSkinJS[categoryName.replace(' FARBE', '')] !== undefined)) {
                let originalValue;
                if (categoryName.includes('FARBE')) {
                    const baseCategory = categoryName.replace(' FARBE', '');
                    if (originalSkinJS[baseCategory]) {
                        originalValue = originalSkinJS[baseCategory].texture;
                    }
                } else {
                    if (originalSkinJS[categoryName]) {
                        originalValue = originalSkinJS[categoryName].drawable;
                    }
                }

                if (originalValue !== undefined && parseInt(slider.value, 10) !== originalValue) {
                     changedOutfitData[categoryName] = parseInt(slider.value, 10);
                }
            }
        });

        // Send the changed outfit data and method to the server
        fetch(`https://ali_clothingshop/purchase`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                changedOutfit: changedOutfitData,
                method: method
            })
        });

        // Reset the button state after purchase attempt
        btn.removeAttribute('data-confirm');
         btn.innerHTML = (method === 'bank' ? 'BANK' : 'BAR');

    } else {
        // If the button is not in confirmation state, set it to confirmation
        updatePriceDisplay();
        btn.setAttribute('data-confirm', 'true');
        btn.textContent = `${currentPrice}$ | BESTÄTIGEN`;
    }
}

function updateAllSliders(maxValues, currentSkin = null) {
    document.querySelectorAll('.clothing-item').forEach(item => {
        const categoryName = item.querySelector('.item-name').textContent;
        if (maxValues[categoryName] !== undefined) {
            const slider = item.querySelector('.slider');
            const valueInput = item.querySelector('.slider-value');
            const sliderControls = item.querySelector('.slider-controls');
            
            if (!slider || !sliderControls) return;
            
            // Get or create min and max labels
            let minLabel = sliderControls.querySelector('.slider-label:first-child');
            let maxLabel = sliderControls.querySelector('.slider-label:last-child');
            
            if (!minLabel) {
                minLabel = document.createElement('div');
                minLabel.className = 'slider-label';
                sliderControls.insertBefore(minLabel, slider);
            }
            
            if (!maxLabel) {
                maxLabel = document.createElement('div');
                maxLabel.className = 'slider-label';
                sliderControls.appendChild(maxLabel);
            }

            // Special handling for KOPFBEDECKUNG which can be -1
            let min = 0;
            let max = Math.max(0, maxValues[categoryName]);
            
            if (categoryName === 'KOPFBEDECKUNG') {
                min = -1;
                // Ensure max is at least -1
                max = Math.max(-1, maxValues[categoryName]);
            }
            
            // Update slider attributes
            slider.min = min;
            slider.max = max;
            slider.step = 1;
            
            // Update input attributes
            if (valueInput) {
                valueInput.min = min;
                valueInput.max = max;
                valueInput.step = 1;
            }
            
            // Update labels
            minLabel.textContent = min.toString();
            maxLabel.textContent = max.toString();
            
            // Set current value from skin if available
            if (currentSkin) {
                let currentValue = 0;
                if (categoryName.includes('FARBE')) {
                    const baseCategory = categoryName.replace(' FARBE', '');
                    if (currentSkin[baseCategory] && currentSkin[baseCategory].texture !== undefined) {
                        currentValue = currentSkin[baseCategory].texture;
                    }
                } else if (currentSkin[categoryName] && currentSkin[categoryName].drawable !== undefined) {
                    currentValue = currentSkin[categoryName].drawable;
                }
                
                // Ensure value is within bounds
                currentValue = Math.max(0, Math.min(max, currentValue));
                
                // Update UI
                slider.value = currentValue;
                if (valueInput) valueInput.value = currentValue;
            } else {
                slider.value = 0;
                if (valueInput) valueInput.value = 0;
            }
        }
    });
    updatePriceDisplay(); // Update price after setting sliders
}

document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('.slider').forEach(slider => {
        const valueInput = slider.closest('.slider-container').querySelector('.slider-value');
        const categoryName = slider.closest('.clothing-item').querySelector('.item-name').textContent;

        const updateClothing = (cat, val) => {
            fetch(`https://ali_clothingshop/updateClothing`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ category: cat, value: val })
            });
        };

        slider.addEventListener('input', (e) => {
            valueInput.value = e.target.value;
            updateClothing(categoryName, e.target.value);
            updatePriceDisplay(); // Force price update on slider change
        });

        valueInput.addEventListener('input', (e) => {
            if (parseInt(e.target.value) > parseInt(slider.max)) e.target.value = slider.max;
            slider.value = e.target.value;
            updateClothing(categoryName, e.target.value);
             updatePriceDisplay(); // Force price update on input change
        });
    });

    document.querySelectorAll('.is-category').forEach(item => item.classList.remove('expanded'));
});

window.addEventListener('message', function(event) {
    const { action, pricePerItem, maxValues, currentSkin } = event.data; // Renamed price to pricePerItem
    switch (action) {
        case 'show':
            document.body.style.display = 'flex';
            originalSkinJS = currentSkin; // Store original skin
            itemPrice = pricePerItem; // Store price per item
            updateAllSliders(maxValues, currentSkin);
            document.querySelector('.clothing-store').classList.add('show');
            break;
        case 'hide':
            document.body.style.display = 'none';
            document.querySelector('.clothing-store').classList.remove('show');
            resetPurchaseButtons();
            break;
        case 'updateMaxValues':
            updateAllSliders(maxValues);
            break;
        case 'setCursor':
            document.body.style.cursor = event.data.visible ? 'default' : 'none';
            break;
    }
});

document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        fetch(`https://ali_clothingshop/close`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({})
        });
    }
});

document.addEventListener('click', function(event) {
    const purchaseSection = document.querySelector('.purchase-section');
    if (purchaseSection && !purchaseSection.contains(event.target)) {
        resetPurchaseButtons();
    }
});

document.addEventListener('mousedown', function(event) {
    if (event.button === 2) {
        event.preventDefault();
        isRightMouseDown = true;
        fetch(`https://ali_clothingshop/setRotationStatus`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ status: true })
        });
    }
});

document.addEventListener('mouseup', function(event) {
    if (event.button === 2) {
        isRightMouseDown = false;
        fetch(`https://ali_clothingshop/setRotationStatus`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ status: false })
        });
    }
});


document.addEventListener('auxclick', function(event) {
    if (event.button === 1) {
        event.preventDefault();
        fetch(`https://ali_clothingshop/toggleCamera`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({})
        });
    }
});

document.addEventListener('mousemove', function(event) {
    if (isRightMouseDown) {
        fetch(`https://ali_clothingshop/rotateCharacter`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ movementX: event.movementX })
        });
    }
});


document.addEventListener('contextmenu', event => event.preventDefault());