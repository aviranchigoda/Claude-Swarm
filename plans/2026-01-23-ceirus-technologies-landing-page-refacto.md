# Ceirus Technologies Landing Page Refactoring Plan

## Overview
Refactor the static HTML website into a scalable, production-ready single `index.html` file with dynamic rendering, mobile responsiveness, and enhanced interactivity.

## Requirements Summary
1. **JavaScript-Based Rendering** - Replace hardcoded cards with dynamic rendering from `products` array
2. **Mobile Hamburger Menu** - Responsive navigation for mobile devices
3. **Contact Modal** - Popup form instead of plain email link
4. **Scroll Animations** - Fade-in effects for cards as user scrolls
5. **Search/Filter** - Real-time product filtering

---

## Implementation Plan

### 1. JavaScript Product Data Structure
Create a `products` array containing the 4 existing products plus 4 additional example products to demonstrate scalability:

```javascript
const products = [
    { category: "Social API", title: "Meta Workflow Engine", description: "..." },
    { category: "Data Pipeline", title: "LinkedIn Insight Connect", description: "..." },
    // ... additional products
];
```

### 2. Dynamic Card Rendering
- Create `renderProducts(productsArray)` function
- Generate card HTML from product data
- Insert into `.grid` container using `innerHTML`
- Include "no results" message for empty searches

### 3. Mobile Hamburger Menu
**CSS:**
- Hide hamburger by default, show on screens ≤768px
- Animated three-bar icon with transform to X when active
- Slide-in navigation panel from right side

**JavaScript:**
- Toggle `active` class on hamburger click
- Close menu when clicking outside or on links

### 4. Contact Modal
**HTML Structure:**
- Overlay container with centered modal box
- Form with Name, Email, Message fields
- Close button (X) in header

**CSS:**
- Fixed positioning with semi-transparent backdrop
- Scale animation on open/close
- Form styling consistent with site theme

**JavaScript:**
- Open modal on "Contact Us" button click
- Close on X, overlay click, or Escape key
- Form submission handler (console log + alert for demo)

### 5. Scroll Fade-in Animation
**CSS:**
- Cards start with `opacity: 0` and `transform: translateY(30px)`
- `.visible` class transitions to normal state
- Staggered delays based on card index

**JavaScript:**
- Use Intersection Observer API
- Add `.visible` class when card enters viewport
- Unobserve after animation triggers (one-time effect)

### 6. Search/Filter Functionality
**HTML:**
- Search input above the product grid
- Placeholder text indicating searchable fields

**JavaScript:**
- Filter on `input` event (real-time)
- Match against title, category, and description (case-insensitive)
- Re-render grid with filtered results

---

## File Structure
Single file: `/home/ai_dev/ceirus/index.html`

All CSS in `<style>` block, all JS in `<script>` block at end of body.

---

## Deliverable Features
| Feature | Implementation |
|---------|---------------|
| Product array | `products` variable with 8 sample products |
| Dynamic rendering | `renderProducts()` function |
| Hamburger menu | CSS transforms + JS toggle |
| Contact modal | Overlay + form with open/close handlers |
| Scroll animations | Intersection Observer + CSS transitions |
| Search filter | Real-time input filtering |

---

## Verification
1. Open `index.html` in browser
2. Test mobile menu by resizing to ≤768px width
3. Click "Contact Us" to verify modal opens/closes
4. Scroll down to observe fade-in animations
5. Type in search bar to verify real-time filtering
6. Add new product to array to confirm scalability
