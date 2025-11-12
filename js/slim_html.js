const cleanHtml = () => {
  // const markHiddenElements = () => {
  //   const hiddenEls = new Set();
  //   document.querySelectorAll('*').forEach(el => {
  //     if (el.offsetWidth === 0 && el.offsetHeight === 0) {
  //       hiddenEls.add(el);
  //     }
  //   });

  //   document.querySelectorAll('a, button').forEach(el => {
  //     let current = el;
  //     let isHidden = false;
  //     while (current) {
  //       if (hiddenEls.has(current)) {
  //         isHidden = true;
  //         break;
  //       }
  //       current = current.parentElement;
  //     }
  //     if (isHidden) {
  //       el.setAttribute('data-temp-hidden', 'true');
  //     }
  //   });
  // };

  // markHiddenElements();

  const doc = document.documentElement.cloneNode(true);

  // Set disabled on hidden elements in the clone
  // doc.querySelectorAll('[data-temp-hidden]').forEach(el => {
  //   el.disabled = true;
  // });

  // Remove all script, style, link, br, and svg elements
  doc.querySelectorAll('script, noscript, style, link, br, svg').forEach(el => el.remove());

  function cleanAttributes(element) {
    const attrs = Array.from(element.attributes);
    attrs.forEach(attr => {
      const keepAttrs = ['id', 'action', 'href', 'role', 'aria-label', 'aria-hidden', 'aria-pressed', 'aria-checked', 'aria-selected', 'disabled'];
      if (!keepAttrs.includes(attr.name)) {
        element.removeAttribute(attr.name);
      }
    });
  }

  // Apply attribute cleaning to all elements
  doc.querySelectorAll('*').forEach(cleanAttributes);

  // Replace p and span elements with their text content
  doc.querySelectorAll('p, span').forEach(el => {
    const text = el.textContent;
    el.replaceWith(text);
  });

  // Remove empty tags (elements with no text content or only whitespace/newlines)
  let removed = true;
  while (removed) {
    removed = false;
    const elements = doc.querySelectorAll('*');
    for (let el of elements) {
      if (el.textContent.trim() === '' && el !== doc) {
        el.remove();
        removed = true;
        break; // Restart the loop to check for newly emptied elements
      }
    }
  }

  return doc.outerHTML;
};

const trimWhitespaces = (html) => {
  // Remove trailing whitespaces and consecutive blank lines, keeping max 1 blank line
  return html
    .replace(/[ \t]+$/gm, '')  // remove trailing spaces and tabs from each line
    .replace(/\n{3,}/g, '\n\n');  // remove consecutive blank lines
};

const paginateHtml = (html, requestedPage) => {
  const pageSize = 80000;
  const pages = [];
  console.log('html length:', html.length);
  for (let i = 0; i < html.length; i += pageSize) {
    pages.push(html.slice(i, i + pageSize));
  }
  return pages[requestedPage - 1] || '';
};

const addVpsbIds = () => {
  const targetElements = ['section', 'div', 'table', 'form', 'a', 'ul', 'input', 'h1', 'h2', 'h3', 'button', 'svg'];
  let idCounter = 0;

  document.querySelectorAll(targetElements.join(', ')).forEach(element => {
    if (!element.hasAttribute('id')) {
      element.setAttribute('id', `vpsb-${++idCounter}`);
    }
    if (idCounter > 10000) {
      console.warn('Too many elements, stopping adding vpsb-ids at 10000');
      return;
    }
  });
  console.log(`Added vpsb-ids to ${idCounter} elements`);
};

module.exports = { cleanHtml, trimWhitespaces, paginateHtml, addVpsbIds };