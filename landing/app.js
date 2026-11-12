// Small, dependency-free behaviour for the landing page.
(function () {
  'use strict';

  // Author contact. The address is assembled at runtime so simple scrapers don't harvest it.
  // Set linkedin to your profile URL (for example https://www.linkedin.com/in/your-name) to show the link.
  var AUTHOR = {
    name: 'Erick',
    mailUser: 'erickomari243',
    mailDomain: 'gmail.com',
    linkedin: ''
  };

  // Flashcards: click to turn over.
  document.querySelectorAll('.card').forEach(function (card) {
    card.addEventListener('click', function () {
      var open = card.getAttribute('aria-expanded') === 'true';
      card.setAttribute('aria-expanded', String(!open));
    });
  });

  // Homework checklists remember ticks on this device only. Storage can be unavailable
  // (private windows, blocked site data), so every access is guarded.
  var KEY = 'linux-iamlab-homework-v1';
  var saved = {};
  try { saved = JSON.parse(localStorage.getItem(KEY) || '{}') || {}; } catch (e) { saved = {}; }
  var stamp = document.querySelector('.done-stamp');
  var boxes = Array.prototype.slice.call(document.querySelectorAll('.checklist input[type="checkbox"]'));
  boxes.forEach(function (box, i) {
    var list = box.closest('.checklist').getAttribute('data-list');
    var id = list + '-' + i;
    box.id = 'hw-' + id;
    if (saved[id]) box.checked = true;
    box.addEventListener('change', function () {
      saved[id] = box.checked;
      try { localStorage.setItem(KEY, JSON.stringify(saved)); } catch (e) { /* not saved; still works this visit */ }
      updateStamp();
    });
  });
  function updateStamp() {
    if (!stamp) return;
    stamp.hidden = !boxes.every(function (b) { return b.checked; });
  }
  updateStamp();

  // Contact: opens the visitor's own email app with the message filled in.
  var form = document.getElementById('contact-form');
  if (form) {
    var error = form.querySelector('.letter__error');
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var name = form.elements.name.value.trim();
      var message = form.elements.message.value.trim();
      if (!name || !message) { error.hidden = false; return; }
      error.hidden = true;
      var to = AUTHOR.mailUser + '@' + AUTHOR.mailDomain;
      var subject = encodeURIComponent('Linux IAM Lab question from ' + name);
      var body = encodeURIComponent(message + '\n\n-- ' + name);
      window.location.href = 'mailto:' + to + '?subject=' + subject + '&body=' + body;
    });
  }
  // "Ask for access" buttons open an access request email to the author.
  document.querySelectorAll('[data-ask-access]').forEach(function (a) {
    a.href = 'mailto:' + AUTHOR.mailUser + '@' + AUTHOR.mailDomain +
      '?subject=' + encodeURIComponent('Linux IAM Lab access request') +
      '&body=' + encodeURIComponent('Hi Erick,\n\nI would like access to the Linux IAM Lab.\n\nName:\nWhy I want to take the lab:\n');
  });

  var li = document.getElementById('linkedin-link');
  if (li && AUTHOR.linkedin) { li.href = AUTHOR.linkedin; li.hidden = false; }
})();
