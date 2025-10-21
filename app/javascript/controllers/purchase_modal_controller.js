import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "itemName", "amountInput"]
  static values = { itemId: Number, itemCost: Number }

  open(event) {
    const itemId = event.params.itemId
    const itemName = event.params.itemName
    const itemCost = event.params.itemCost

    this.itemIdValue = itemId
    this.itemNameTarget.textContent = itemName
    this.amountInputTarget.value = itemCost

    this.modalTarget.classList.remove("hidden")
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.amountInputTarget.value = ""
  }

  async submit(event) {
    event.preventDefault()

    const amount = this.amountInputTarget.value
    if (!amount || parseFloat(amount) <= 0) {
      alert("Please enter a valid amount")
      return
    }

    try {
      const response = await fetch(`/wish_list_items/${this.itemIdValue}/mark_as_purchased`, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: JSON.stringify({ amount: parseFloat(amount) })
      })

      if (response.ok) {
        window.location.reload()
      } else {
        const data = await response.json()
        alert(`Error: ${data.error || 'Failed to mark as purchased'}`)
      }
    } catch (error) {
      console.error("Error:", error)
      alert("An error occurred while marking the item as purchased")
    }
  }
}
