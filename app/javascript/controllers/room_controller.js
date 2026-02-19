import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = {
    roomCode: String,
    participantId: String,
    isAdmin: Boolean
  }

  static targets = ["participantsList", "voteButtons", "voteCard", "revealButton", "resetButton", "shareInput", "copyButton", "content"]

  connect() {
    const consumer = window.pokerCable ??= createConsumer()
    this.subscription = consumer.subscriptions.create(
      {
        channel: "RoomChannel",
        room_code: this.roomCodeValue,
        participant_id: this.participantIdValue
      },
      {
        received: (data) => this.handleBroadcast(data)
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  vote(event) {
    const point = parseInt(event.currentTarget.dataset.point, 10)
    this.subscription.perform("vote", { point })
  }

  reveal() {
    this.subscription.perform("reveal")
  }

  resetVoting() {
    this.subscription.perform("reset_voting")
  }

  copyLink(event) {
    const input = this.shareInputTarget
    const text = input.value
    input.select()
    input.setSelectionRange(0, 99999)

    const showCopied = () => {
      if (this.hasCopyButtonTarget) {
        const btn = this.copyButtonTarget
        const original = btn.textContent
        btn.textContent = "Copied!"
        setTimeout(() => { btn.textContent = original }, 2000)
      }
    }

    if (navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(text).then(showCopied).catch(() => this.fallbackCopy(input, showCopied))
    } else {
      this.fallbackCopy(input, showCopied)
    }
  }

  fallbackCopy(input, onSuccess) {
    try {
      const copied = document.execCommand("copy")
      if (copied) onSuccess()
    } catch (_e) {
      // Selection is already in place; user can Cmd+C / Ctrl+C
      onSuccess()
    }
  }

  handleBroadcast(data) {
    this.updateParticipants(data.participants, data.revealed)
    this.updateVoteCards(data.participants)
    if (this.isAdminValue) {
      this.updateAdminButtons(data.everyone_voted, data.revealed)
    }
  }

  updateParticipants(participants, revealed) {
    const participantId = this.participantIdValue
    const html = Object.entries(participants).map(([id, data]) => {
      const voteDisplay = revealed ? (data.vote ?? "—") : (data.vote ? "✓" : "—")
      return `
        <div class="participant" data-participant-id="${id}">
          <span class="participant__name">${escapeHtml(data.name)}</span>
          <span class="participant__vote" data-vote>${voteDisplay}</span>
        </div>
      `
    }).join("")
    this.participantsListTarget.innerHTML = html
  }

  updateVoteCards(participants) {
    const myVote = participants[this.participantIdValue]?.vote
    this.voteCardTargets.forEach((card) => {
      const point = parseInt(card.dataset.point, 10)
      card.classList.toggle("voting__card--selected", myVote === point)
    })
  }

  updateAdminButtons(everyoneVoted, revealed) {
    if (this.hasRevealButtonTarget) {
      this.revealButtonTarget.disabled = !everyoneVoted || revealed
    }
    if (this.hasResetButtonTarget) {
      this.resetButtonTarget.disabled = !revealed
    }
  }
}

function escapeHtml(text) {
  const div = document.createElement("div")
  div.textContent = text
  return div.innerHTML
}
