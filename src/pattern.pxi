

cdef class Pattern:
    cdef readonly int flags
    cdef readonly int groups
    cdef readonly object pattern

    cdef _re2.RE2 * re_pattern
    cdef bint encoded
    cdef object __weakref__

    def __dealloc__(self):
        del self.re_pattern

    def __repr__(self):
        return 're2.compile(%r, %r)' % (self.pattern, self.flags)

    cdef _search(self, string, int pos, int endpos, _re2.re2_Anchor anchoring):
        """Scan through string looking for a match, and return a corresponding
        Match instance. Return None if no position in the string matches."""
        cdef Py_ssize_t size
        cdef int result
        cdef char * cstring
        cdef int encoded = 0
        cdef _re2.StringPiece * sp
        cdef Match m = Match(self, self.groups + 1)

        if hasattr(string, 'tostring'):
            string = string.tostring()

        string = unicode_to_bytes(string, &encoded)

        if pystring_to_cstring(string, &cstring, &size) == -1:
            raise TypeError("expected string or buffer")

        if 0 <= endpos <= pos or pos > size:
            return None
        if 0 <= endpos < size
            size = endpos

        sp = new _re2.StringPiece(cstring, size)
        with nogil:
            result = self.re_pattern.Match(
                    sp[0],
                    <int>pos,
                    <int>size,
                    anchoring,
                    m.matches,
                    self.groups + 1)

        del sp
        if result == 0:
            return None
        m.encoded = encoded
        m.named_groups = _re2.addressof(self.re_pattern.NamedCapturingGroups())
        m.nmatches = self.groups + 1
        m.string = string
        m.pos = pos
        if endpos == -1:
            m.endpos = len(string)
        else:
            m.endpos = endpos
        return m

    def search(self, object string, int pos=0, int endpos=-1):
        """Scan through string looking for a match, and return a corresponding
        Match instance. Return None if no position in the string matches."""
        return self._search(string, pos, endpos, _re2.UNANCHORED)

    def match(self, object string, int pos=0, int endpos=-1):
        """Matches zero or more characters at the beginning of the string."""
        return self._search(string, pos, endpos, _re2.ANCHOR_START)

    def _print_pattern(self):
        cdef _re2.cpp_string * s
        s = <_re2.cpp_string *>_re2.addressofs(self.re_pattern.pattern())
        print(cpp_to_bytes(s[0]).decode('utf8'))

    def finditer(self, object string, int pos=0, int endpos=-1):
        """Yield all non-overlapping matches of pattern in string as Match
        objects."""
        cdef Py_ssize_t size
        cdef int result
        cdef char * cstring
        cdef _re2.StringPiece * sp
        cdef Match m
        cdef int encoded = 0

        string = unicode_to_bytes(string, &encoded)
        if pystring_to_cstring(string, &cstring, &size) == -1:
            raise TypeError("expected string or buffer")

        if endpos != -1 and endpos < size:
            size = endpos

        sp = new _re2.StringPiece(cstring, size)

        while True:
            m = Match(self, self.groups + 1)
            with nogil:
                result = self.re_pattern.Match(
                        sp[0],
                        <int>pos,
                        <int>size,
                        _re2.UNANCHORED,
                        m.matches,
                        self.groups + 1)
            if result == 0:
                break
            m.encoded = encoded
            m.named_groups = _re2.addressof(
                    self.re_pattern.NamedCapturingGroups())
            m.nmatches = self.groups + 1
            m.string = string
            m.pos = pos
            if endpos == -1:
                m.endpos = len(string)
            else:
                m.endpos = endpos
            yield m
            if pos == size:
                break
            # offset the pos to move to the next point
            if m.matches[0].length() == 0:
                pos += 1
            else:
                pos = m.matches[0].data() - cstring + m.matches[0].length()
        del sp

    def findall(self, object string, int pos=0, endpos=None):
        """Return all non-overlapping matches of pattern in string as a list
        of strings."""
        cdef Py_ssize_t size
        cdef int result
        cdef char * cstring
        cdef _re2.StringPiece * sp
        cdef Match m
        cdef list resultlist = []
        cdef int encoded = 0

        string = unicode_to_bytes(string, &encoded)
        if pystring_to_cstring(string, &cstring, &size) == -1:
            raise TypeError("expected string or buffer")

        if endpos is not None and endpos < size:
            size = endpos

        sp = new _re2.StringPiece(cstring, size)

        while True:
            # FIXME: can probably avoid creating Match objects
            m = Match(self, self.groups + 1)
            with nogil:
                result = self.re_pattern.Match(
                        sp[0],
                        <int>pos,
                        <int>size,
                        _re2.UNANCHORED,
                        m.matches,
                        self.groups + 1)
            if result == 0:
                break
            m.encoded = encoded
            m.named_groups = _re2.addressof(
                    self.re_pattern.NamedCapturingGroups())
            m.nmatches = self.groups + 1
            m.string = string
            m.pos = pos
            if endpos is not None:
                m.endpos = len(string)
            else:
                m.endpos = endpos
            if self.groups > 1:
                resultlist.append(m.groups(""))
            else:
                resultlist.append(m.group(self.groups))
            if pos == size:
                break
            # offset the pos to move to the next point
            if m.matches[0].length() == 0:
                pos += 1
            else:
                pos = m.matches[0].data() - cstring + m.matches[0].length()
        del sp
        return resultlist

    def split(self, string, int maxsplit=0):
        """split(string[, maxsplit = 0]) --> list

        Split a string by the occurrences of the pattern."""
        cdef Py_ssize_t size
        cdef int result
        cdef int pos = 0
        cdef int lookahead = 0
        cdef int num_split = 0
        cdef char * cstring
        cdef _re2.StringPiece * sp
        cdef _re2.StringPiece * matches
        cdef list resultlist = []
        cdef int encoded = 0

        if maxsplit < 0:
            maxsplit = 0

        string = unicode_to_bytes(string, &encoded)
        if pystring_to_cstring(string, &cstring, &size) == -1:
            raise TypeError("expected string or buffer")

        matches = _re2.new_StringPiece_array(self.groups + 1)
        sp = new _re2.StringPiece(cstring, size)

        while True:
            with nogil:
                result = self.re_pattern.Match(
                        sp[0],
                        <int>(pos + lookahead),
                        <int>size,
                        _re2.UNANCHORED,
                        matches,
                        self.groups + 1)
            if result == 0:
                break

            match_start = matches[0].data() - cstring
            match_end = match_start + matches[0].length()

            # If an empty match, just look ahead until you find something
            if match_start == match_end:
                if pos + lookahead == size:
                    break
                lookahead += 1
                continue

            if encoded:
                resultlist.append(
                        char_to_unicode(&sp.data()[pos], match_start - pos))
            else:
                resultlist.append(sp.data()[pos:match_start])
            if self.groups > 0:
                for group in range(self.groups):
                    if matches[group + 1].data() == NULL:
                        resultlist.append(None)
                    else:
                        if encoded:
                            resultlist.append(char_to_unicode(
                                    matches[group + 1].data(),
                                    matches[group + 1].length()))
                        else:
                            resultlist.append(matches[group + 1].data()[:
                                        matches[group + 1].length()])

            # offset the pos to move to the next point
            pos = match_end
            lookahead = 0

            num_split += 1
            if maxsplit and num_split >= maxsplit:
                break

        if encoded:
            resultlist.append(
                    char_to_unicode(&sp.data()[pos], sp.length() - pos))
        else:
            resultlist.append(sp.data()[pos:])
        _re2.delete_StringPiece_array(matches)
        del sp
        return resultlist

    def sub(self, repl, string, int count=0):
        """sub(repl, string[, count = 0]) --> newstring

        Return the string obtained by replacing the leftmost non-overlapping
        occurrences of pattern in string by the replacement repl."""
        return self.subn(repl, string, count)[0]

    def subn(self, repl, string, int count=0):
        """subn(repl, string[, count = 0]) --> (newstring, number of subs)

        Return the tuple (new_string, number_of_subs_made) found by replacing
        the leftmost non-overlapping occurrences of pattern with the
        replacement repl."""
        cdef Py_ssize_t size
        cdef char * cstring
        cdef _re2.cpp_string * fixed_repl
        cdef _re2.StringPiece * sp
        cdef _re2.cpp_string * input_str
        cdef total_replacements = 0
        cdef int string_encoded = 0
        cdef int repl_encoded = 0

        if callable(repl):
            # This is a callback, so let's use the custom function
            return self._subn_callback(repl, string, count)

        string = unicode_to_bytes(string, &string_encoded)
        repl = unicode_to_bytes(repl, &repl_encoded)
        if pystring_to_cstring(repl, &cstring, &size) == -1:
            raise TypeError("expected string or buffer")

        fixed_repl = NULL
        cdef _re2.const_char_ptr s = cstring
        cdef _re2.const_char_ptr end = s + size
        cdef int c = 0
        while s < end:
            c = s[0]
            if (c == b'\\'):
                s += 1
                if s == end:
                    raise RegexError("Invalid rewrite pattern")
                c = s[0]
                if c == b'\\' or (c >= b'0' and c <= b'9'):
                    if fixed_repl != NULL:
                        fixed_repl.push_back(b'\\')
                        fixed_repl.push_back(c)
                else:
                    if fixed_repl == NULL:
                        fixed_repl = new _re2.cpp_string(
                                cstring, s - cstring - 1)
                    if c == b'n':
                        fixed_repl.push_back(b'\n')
                    else:
                        fixed_repl.push_back(b'\\')
                        fixed_repl.push_back(b'\\')
                        fixed_repl.push_back(c)
            else:
                if fixed_repl != NULL:
                    fixed_repl.push_back(c)

            s += 1
        if fixed_repl != NULL:
            sp = new _re2.StringPiece(fixed_repl.c_str())
        else:
            sp = new _re2.StringPiece(cstring, size)

        input_str = new _re2.cpp_string(string)
        if not count:
            total_replacements = _re2.pattern_GlobalReplace(
                    input_str, self.re_pattern[0], sp[0])
        elif count == 1:
            total_replacements = _re2.pattern_Replace(
                    input_str, self.re_pattern[0], sp[0])
        else:
            del fixed_repl
            del input_str
            del sp
            raise NotImplementedError(
                    "So far pyre2 does not support custom replacement counts")

        if string_encoded or (repl_encoded and total_replacements > 0):
            result = cpp_to_unicode(input_str[0])
        else:
            result = cpp_to_bytes(input_str[0])
        del fixed_repl
        del input_str
        del sp
        return (result, total_replacements)

    def _subn_callback(self, callback, string, int count=0):
        # This function is probably the hardest to implement correctly.
        # This is my first attempt, but if anybody has a better solution,
        # please help out.
        cdef Py_ssize_t size
        cdef int result
        cdef int endpos
        cdef int pos = 0
        cdef int encoded = 0
        cdef int num_repl = 0
        cdef char * cstring
        cdef _re2.StringPiece * sp
        cdef Match m
        cdef list resultlist = []

        if count < 0:
            count = 0

        string = unicode_to_bytes(string, &encoded)
        if pystring_to_cstring(string, &cstring, &size) == -1:
            raise TypeError("expected string or buffer")

        sp = new _re2.StringPiece(cstring, size)

        try:
            while True:
                m = Match(self, self.groups + 1)
                with nogil:
                    result = self.re_pattern.Match(
                            sp[0],
                            <int>pos,
                            <int>size,
                            _re2.UNANCHORED,
                            m.matches,
                            self.groups + 1)
                if result == 0:
                    break

                endpos = m.matches[0].data() - cstring
                if encoded:
                    resultlist.append(
                            char_to_unicode(&sp.data()[pos], endpos - pos))
                else:
                    resultlist.append(sp.data()[pos:endpos])
                pos = endpos + m.matches[0].length()

                m.encoded = encoded
                m.named_groups = _re2.addressof(
                        self.re_pattern.NamedCapturingGroups())
                m.nmatches = self.groups + 1
                m.string = string
                resultlist.append(callback(m) or '')

                num_repl += 1
                if count and num_repl >= count:
                    break

            if encoded:
                resultlist.append(
                        char_to_unicode(&sp.data()[pos], sp.length() - pos))
                return (u''.join(resultlist), num_repl)
            else:
                resultlist.append(sp.data()[pos:])
                return (b''.join(resultlist), num_repl)
        finally:
            del sp

_cache = {}
_cache_repl = {}

_MAXCACHE = 100

def compile(pattern, int flags=0, int max_mem=8388608):
    cachekey = (type(pattern), pattern, flags)
    if cachekey in _cache:
        return _cache[cachekey]
    p = _compile(pattern, flags, max_mem)

    if len(_cache) >= _MAXCACHE:
        _cache.popitem()
    _cache[cachekey] = p
    return p


WHITESPACE = b' \t\n\r\v\f'


cdef class Tokenizer:
    cdef bytes string
    cdef bytes next
    cdef int length
    cdef int index

    def __init__(self, bytes string):
        self.string = string
        self.length = len(string)
        self.index = 0
        self._next()

    cdef _next(self):
        cdef bytes ch
        if self.index >= self.length:
            self.next = None
            return
        ch = self.string[self.index:self.index + 1]
        if ch[0:1] == b'\\':
            if self.index + 2 > self.length:
                raise RegexError("bogus escape (end of line)")
            ch = self.string[self.index:self.index + 2]
            self.index += 1
        self.index += 1
        # FIXME: return indices instead of creating new bytes objects
        self.next = ch

    cdef bytes get(self):
        cdef bytes this = self.next
        self._next()
        return this


def prepare_pattern(object pattern, int flags):
    cdef bytearray result = bytearray()
    cdef bytes this
    cdef Tokenizer source = Tokenizer(pattern)

    if flags & (_S | _M):
        result.extend(b'(?')
        if flags & _S:
            result.append(b's')
        if flags & _M:
            result.append(b'm')
        result.append(b')')

    while True:
        this = source.get()
        if this is None:
            break
        if flags & _X:
            if this in WHITESPACE:
                continue
            if this == b"#":
                while True:
                    this = source.get()
                    if this in (None, b'\n'):
                        break
                continue

        if this[0:1] != b'[' and this[0:1] != b'\\':
            result.extend(this)
            continue

        elif this == b'[':
            result.extend(this)
            while True:
                this = source.get()
                if this is None:
                    raise RegexError("unexpected end of regular expression")
                elif this == b']':
                    result.extend(this)
                    break
                elif this[0:1] == b'\\':
                    if flags & _U:
                        if this[1:2] == b'd':
                            result.extend(br'\p{Nd}')
                        elif this[1:2] == b'w':
                            result.extend(br'_\p{L}\p{Nd}')
                        elif this[1:2] == b's':
                            result.extend(br'\s\p{Z}')
                        elif this[1:2] == b'D':
                            result.extend(br'\P{Nd}')
                        elif this[1:2] == b'W':
                            # Since \w and \s are made out of several character
                            # groups, I don't see a way to convert their
                            # complements into a group without rewriting the
                            # whole expression, which seems too complicated.
                            raise CharClassProblemException(repr(this))
                        elif this[1:2] == b'S':
                            raise CharClassProblemException(repr(this))
                        else:
                            result.extend(this)
                    else:
                        result.extend(this)
                else:
                    result.extend(this)
        elif this[0:1] == b'\\':
            if b'8' <= this[1:2] <= b'9':
                raise BackreferencesException('%r %r' % (this, pattern))
            elif b'1' <= this[1:2] <= b'7':
                if source.next and source.next in b'1234567':
                    this += source.get()
                    if source.next and source.next in b'1234567':
                        # all clear, this is an octal escape
                        result.extend(this)
                    else:
                        raise BackreferencesException('%r %r' % (this, pattern))
                else:
                    raise BackreferencesException('%r %r' % (this, pattern))
            elif flags & _U:
                if this[1:2] == b'd':
                    result.extend(br'\p{Nd}')
                elif this[1:2] == b'w':
                    result.extend(br'[_\p{L}\p{Nd}]')
                elif this[1:2] == b's':
                    result.extend(br'[\s\p{Z}]')
                elif this[1:2] == b'D':
                    result.extend(br'[^\p{Nd}]')
                elif this[1:2] == b'W':
                    result.extend(br'[^_\p{L}\p{Nd}]')
                elif this[1:2] == b'S':
                    result.extend(br'[^\s\p{Z}]')
                else:
                    result.extend(this)
            else:
                result.extend(this)

    return <bytes>result


def _compile(object pattern, int flags=0, int max_mem=8388608):
    """Compile a regular expression pattern, returning a pattern object."""
    cdef char * string
    cdef Py_ssize_t length
    cdef _re2.StringPiece * s
    cdef _re2.Options opts
    cdef int error_code
    cdef int encoded = 0

    if isinstance(pattern, (Pattern, SREPattern)):
        if flags:
            raise ValueError(
                    'Cannot process flags argument with a compiled pattern')
        return pattern

    cdef object original_pattern = pattern
    pattern = unicode_to_bytes(pattern, &encoded)
    try:
        pattern = prepare_pattern(pattern, flags)
    except BackreferencesException:
        error_msg = "Backreferences not supported"
        if current_notification == <int>FALLBACK_EXCEPTION:
            # Raise an exception regardless of the type of error.
            raise RegexError(error_msg)
        elif current_notification == <int>FALLBACK_WARNING:
            warnings.warn("WARNING: Using re module. Reason: %s" % error_msg)
        return re.compile(original_pattern, flags)
    except CharClassProblemException:
        error_msg = "\W and \S not supported inside character classes"
        if current_notification == <int>FALLBACK_EXCEPTION:
            # Raise an exception regardless of the type of error.
            raise RegexError(error_msg)
        elif current_notification == <int>FALLBACK_WARNING:
            warnings.warn("WARNING: Using re module. Reason: %s" % error_msg)
        return re.compile(original_pattern, flags)

    # Set the options given the flags above.
    if flags & _I:
        opts.set_case_sensitive(0);

    opts.set_max_mem(max_mem)
    opts.set_log_errors(0)
    opts.set_encoding(_re2.EncodingUTF8)

    # We use this function to get the proper length of the string.
    if pystring_to_cstring(pattern, &string, &length) == -1:
        raise TypeError("first argument must be a string or compiled pattern")
    s = new _re2.StringPiece(string, length)

    cdef _re2.RE2 *re_pattern
    with nogil:
         re_pattern = new _re2.RE2(s[0], opts)

    if not re_pattern.ok():
        # Something went wrong with the compilation.
        del s
        error_msg = cpp_to_bytes(re_pattern.error())
        error_code = re_pattern.error_code()
        del re_pattern
        if current_notification == <int>FALLBACK_EXCEPTION:
            # Raise an exception regardless of the type of error.
            raise RegexError(error_msg)
        elif error_code not in (_re2.ErrorBadPerlOp, _re2.ErrorRepeatSize,
                                _re2.ErrorBadEscape):
            # Raise an error because these will not be fixed by using the
            # ``re`` module.
            raise RegexError(error_msg)
        elif current_notification == <int>FALLBACK_WARNING:
            warnings.warn("WARNING: Using re module. Reason: %s" % error_msg)
        return re.compile(original_pattern, flags)

    cdef Pattern pypattern = Pattern()
    pypattern.pattern = original_pattern
    pypattern.re_pattern = re_pattern
    pypattern.groups = re_pattern.NumberOfCapturingGroups()
    pypattern.encoded = encoded
    pypattern.flags = flags
    del s
    return pypattern

