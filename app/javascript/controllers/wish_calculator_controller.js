import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "nameInput", "costInput", "typeInput", "targetDateInput", "sequentialOrderInput", "percentageInput", "preview", "acceptButton", "timeline"]
  static values = { url: String }

  connect() {
    this.debounceTimer = null
  }

  toggleAccordion(event) {
    event.preventDefault()
    const content = this.formTarget
    const isHidden = content.classList.contains('hidden')

    if (isHidden) {
      content.classList.remove('hidden')
    } else {
      content.classList.add('hidden')
      this.reset()
    }
  }

  updateTypeFields() {
    const type = this.typeInputTarget.value

    // Hide all conditional fields
    if (this.hasTargetDateInputTarget) {
      this.targetDateInputTarget.closest('.field-group').classList.add('hidden')
    }
    if (this.hasSequentialOrderInputTarget) {
      this.sequentialOrderInputTarget.closest('.field-group').classList.add('hidden')
    }
    if (this.hasPercentageInputTarget) {
      this.percentageInputTarget.closest('.field-group').classList.add('hidden')
    }

    // Show relevant field
    if (type === 'target_date' && this.hasTargetDateInputTarget) {
      this.targetDateInputTarget.closest('.field-group').classList.remove('hidden')
    } else if (type === 'sequential' && this.hasSequentialOrderInputTarget) {
      this.sequentialOrderInputTarget.closest('.field-group').classList.remove('hidden')
    } else if (type === 'percentage' && this.hasPercentageInputTarget) {
      this.percentageInputTarget.closest('.field-group').classList.remove('hidden')
    }

    this.updatePreview()
  }

  updatePreview() {
    clearTimeout(this.debounceTimer)

    const name = this.nameInputTarget.value.trim()
    const cost = this.costInputTarget.value
    const type = this.typeInputTarget.value

    if (!name || !cost || !type) {
      this.previewTarget.innerHTML = '<p class="text-sm text-gray-500">Fill out the form to see a preview...</p>'
      this.acceptButtonTarget.disabled = true
      return
    }

    this.acceptButtonTarget.disabled = false

    this.debounceTimer = setTimeout(() => {
      this.fetchPreview()
    }, 500)
  }

  async fetchPreview() {
    const formData = new FormData()
    formData.append('name', this.nameInputTarget.value)
    formData.append('cost', this.costInputTarget.value)
    formData.append('item_type', this.typeInputTarget.value)

    if (this.typeInputTarget.value === 'target_date' && this.hasTargetDateInputTarget) {
      formData.append('target_date', this.targetDateInputTarget.value)
    } else if (this.typeInputTarget.value === 'sequential' && this.hasSequentialOrderInputTarget) {
      formData.append('sequential_order', this.sequentialOrderInputTarget.value)
    } else if (this.typeInputTarget.value === 'percentage' && this.hasPercentageInputTarget) {
      formData.append('percentage', this.percentageInputTarget.value)
    }

    try {
      // Store current marker positions before update
      const oldPositions = this.captureMarkerPositions()

      const response = await fetch(this.urlValue, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: formData
      })

      const data = await response.json()
      this.previewTarget.innerHTML = data.html

      // Update timeline if available
      if (this.hasTimelineTarget && data.timeline) {
        this.timelineTarget.innerHTML = data.timeline

        // Highlight markers that moved
        this.highlightMovedMarkers(oldPositions)
      }
    } catch (error) {
      console.error('Error fetching preview:', error)
      this.previewTarget.innerHTML = '<p class="text-sm text-red-500">Error loading preview</p>'
    }
  }

  captureMarkerPositions() {
    if (!this.hasTimelineTarget) return {}

    const positions = {}
    const markers = this.timelineTarget.querySelectorAll('.timeline-marker')

    markers.forEach(marker => {
      const itemName = marker.dataset.itemName
      const leftStyle = marker.style.left
      if (itemName && leftStyle) {
        positions[itemName] = leftStyle
      }
    })

    return positions
  }

  highlightMovedMarkers(oldPositions) {
    if (!this.hasTimelineTarget) return

    // Small delay to let the DOM update
    setTimeout(() => {
      const markers = this.timelineTarget.querySelectorAll('.timeline-marker')

      markers.forEach(marker => {
        const itemName = marker.dataset.itemName
        const newPosition = marker.style.left
        const oldPosition = oldPositions[itemName]

        // If position changed or is a new marker, add a brief highlight
        if (!oldPosition || oldPosition !== newPosition) {
          const dot = marker.querySelector('.rounded-full')
          if (dot) {
            // Add a pulse animation
            dot.style.transform = 'scale(1.3)'
            setTimeout(() => {
              dot.style.transform = 'scale(1)'
            }, 300)
          }
        }
      })
    }, 50)
  }

  async accept(event) {
    event.preventDefault()

    const formData = new FormData()
    formData.append('wish_list_item[name]', this.nameInputTarget.value)
    formData.append('wish_list_item[cost]', this.costInputTarget.value)
    formData.append('wish_list_item[item_type]', this.typeInputTarget.value)

    if (this.typeInputTarget.value === 'target_date' && this.hasTargetDateInputTarget) {
      formData.append('wish_list_item[target_date]', this.targetDateInputTarget.value)
    } else if (this.typeInputTarget.value === 'sequential' && this.hasSequentialOrderInputTarget) {
      formData.append('wish_list_item[sequential_order]', this.sequentialOrderInputTarget.value)
    } else if (this.typeInputTarget.value === 'percentage' && this.hasPercentageInputTarget) {
      formData.append('wish_list_item[percentage]', this.percentageInputTarget.value)
    }

    try {
      const response = await fetch('/wish_list_items', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: formData
      })

      if (response.ok) {
        // Reload the page to show the new item
        window.location.reload()
      } else {
        alert('Error creating wish list item')
      }
    } catch (error) {
      console.error('Error creating item:', error)
      alert('Error creating wish list item')
    }
  }

  reset() {
    this.nameInputTarget.value = ''
    this.costInputTarget.value = ''
    this.typeInputTarget.value = 'target_date'
    if (this.hasTargetDateInputTarget) this.targetDateInputTarget.value = ''
    if (this.hasSequentialOrderInputTarget) this.sequentialOrderInputTarget.value = ''
    if (this.hasPercentageInputTarget) this.percentageInputTarget.value = ''

    this.previewTarget.innerHTML = '<p class="text-sm text-gray-500">Fill out the form to see a preview...</p>'
    this.acceptButtonTarget.disabled = true
    this.updateTypeFields()
  }
}
