;; import
(use-modules (sqlite3)
             (ice-9 format)
             (ice-9 match)
             (ice-9 time)
             (ice-9 getopt-long)
             (srfi srfi-1)
             (srfi srfi-9)
             (srfi srfi-13)
             (dotenv parser))


;; utils
(define-record-type <time-entry>
  (make-time-entry task date duration)
  time-entry?
  (task     time-entry-task)
  (date     time-entry-date)
  (duration time-entry-duration))

(define (row-to-entry row)
  (match row 
         (#(task date duration) 
          (make-time-entry task date duration))))

(define (sqlite-exec-collect db sql)
  (let ((rows '()) (stmt (sqlite-prepare db sql)))
    (sqlite-map (lambda (row) (set! rows (cons row rows))) stmt)
    (sqlite-finalize stmt)
    rows))

(define select-group "SELECT task, date, SUM(duration) as total_duration
                      FROM time_tracker
                      GROUP BY task, date
                      ORDER BY date DESC, total_duration DESC")

(define (format-duration secs)
  (let ((m (quotient (or secs 0) 60))) 
    (format #f "~ah ~am" (quotient m 60) (remainder m 60))))

(define (format-entry te) 
  (format #f "~10a | ~7a | ~a\n" 
          (time-entry-date te)
          (format-duration (time-entry-duration te)) 
          (time-entry-task te)))

(define (print-entries tes)
  (for-each 
    (lambda (time-entry) 
      (display (format-entry time-entry))) 
    tes)
  (display (format-duration 
             (fold + 0 
                   (map time-entry-duration tes))))
  (display "\n"))

(define (date-entries tes date)
  (filter 
    (lambda (te) (string-contains (time-entry-date te) date)) 
    tes))

(define (today-entries tes)
  (date-entries tes (strftime "%Y-%m-%d" (localtime (current-time)))))

(define (task-entries tes task)
  (filter 
    (lambda (te) (string-contains (time-entry-task te) task)) 
    tes))

(define option-spec
  '((today (single-char #\t) (value #f))
    (date  (single-char #\d) (value #t))
    (task  (single-char #\T) (value #t))
    (help  (single-char #\h) (value #f))))

(define (show-help)
  (display "Usage: work_time [options]\n")
  (display "Options:\n")
  (display "  -t, --today          time entries for today\n")
  (display "  -d, --date <DATE>    time entries for date (YYYY-MM-DD)\n")
  (display "  -T, --task <TASK>    time entries for task\n")
  (display "  -h, --help           this message\n"))


;; main
(load-dotenv)
(define db (sqlite-open (getenv "DB_NAME")))

(let* ((opts (getopt-long (command-line) option-spec))
       (rows (sqlite-exec-collect db select-group))
       (time-entries (map row-to-entry rows)))
  (cond 
    ((option-ref opts 'help #f)     
      (show-help))
    ((option-ref opts 'today #f)     
      (print-entries (today-entries time-entries)))
    ((option-ref opts 'date #f) =>  
      (lambda (d) (print-entries (date-entries time-entries d))))
    ((option-ref opts 'task #f) =>  
      (lambda (t) (print-entries (task-entries time-entries t))))
    (else (print-entries time-entries))))

(sqlite-close db)

;; end
