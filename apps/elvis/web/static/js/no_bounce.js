/*! Based on iNoBounce - v0.1.0
 * https://github.com/lazd/iNoBounce/
 * Copyright (c) 2013 Larry Davis <lazdnet@gmail.com>; Licensed BSD
 */
(function(window, document) {
  // Stores the Y position where the touch started
  let startY = 0

  let handleTouchmove = function(evt) {
    // Get the element that was scrolled upon
    let el = evt.target

    // Check all parent elements for scrollability
    while (el !== document.body) {
      // Get some style properties
      let style = window.getComputedStyle(el)

      if (!style) {
        // If we've encountered an element we can't compute the style for, get out
        break
      }

      // Ignore range input element
      if (el.nodeName === 'INPUT' && el.getAttribute('type') === 'range') {
        return
      }

      // let scrolling = style.getPropertyValue('-webkit-overflow-scrolling')
      let overflowY = style.getPropertyValue('overflow-y')

      // Determine if the element should scroll
      let isScrollable = (overflowY === 'auto' || overflowY === 'scroll')
      let canScroll = el.scrollHeight > el.offsetHeight

      if (isScrollable && canScroll) {
        // Get the current Y position of the touch
        let curY = evt.touches ? evt.touches[0].screenY : evt.screenY

        // Determine if the user is trying to scroll past the top or bottom
        // In this case, the window will bounce, so we have to prevent scrolling completely
        let isAtTop = (startY <= curY && el.scrollTop === 0)
        let isAtBottom = (startY >= curY && el.scrollHeight - el.scrollTop === el.clientHeight)

        // Stop a bounce bug when at the bottom or top of the scrollable element
        if (isAtTop || isAtBottom) {
          evt.preventDefault()
        }

        // No need to continue up the DOM, we've done our job
        return
      }

      // Test the next parent
      el = el.parentNode
    }

    // Stop the bouncing -- no parents are scrollable
    evt.preventDefault()
  }

  let handleTouchstart = function(evt) {
    // Store the first Y position of the touch
    startY = evt.touches ? evt.touches[0].screenY : evt.screenY
  }

  // Listen to a couple key touch events
  window.addEventListener('touchstart', handleTouchstart, false)
  window.addEventListener('touchmove', handleTouchmove, false)
}(window, document))
